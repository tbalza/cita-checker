import time
import random
from seleniumbase import SB
import json
import smtplib
from email.message import EmailMessage
import os
import logging

# Correct the path to match the mounted location in the Docker container
with open('/tmp/values.json') as config_file:
    config = json.load(config_file)

# Email function to alert when appointment is available
def send_email(subject, message, attach_screenshot=False):
    # Load email configuration from values.json
    with open('/tmp/values.json', 'r') as file:
        config = json.load(file)

    sender_email = config['sender_email']
    receiver_email = config['receiver_email']
    password = config['password']
    smtp_server = config['smtp_server']
    smtp_port = config['smtp_port']

    # Create the email message
    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = sender_email  # Fetches values.json
    msg['To'] = receiver_email  # Fetches values.json
    msg.set_content(message)

    # Attach the screenshot if required
    if attach_screenshot:
        screenshot_path = "/tmp/cita_disponible.png"
        if os.path.exists(screenshot_path):
            with open(screenshot_path, 'rb') as f:
                file_data = f.read()
                file_name = os.path.basename(screenshot_path)
                msg.add_attachment(file_data, maintype='image', subtype='png', filename=file_name)

    # Send the email
    try:
        with smtplib.SMTP_SSL(smtp_server, smtp_port) as smtp:  # Fetches values.json
            smtp.login(sender_email, password)  # Fetches values.json
            smtp.send_message(msg)
            logging.info("Email sent successfully!")
    except Exception as e:
        logging.error(f"Error sending email: {e}")

# Set random window to avoid existing rate-limiting by fingerprinting
def set_random_window_size(sb):
    min_width = 800  # Define minimum width
    max_width = 1600  # Define maximum width
    width = random.randint(min_width, max_width)  # Choose a random width within the range
    height = (width * 2) // 3  # Calculate the height based on a 3:2 aspect ratio
    sb.set_window_size(width, height)  # Set the window size with the calculated width and height


#  Set up logging on /tmp/events.log
def setup_logging():
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s %(levelname)s: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        handlers=[
                            logging.FileHandler("/tmp/events.log"),
                            logging.StreamHandler()
                        ])


#  Launch test
def check_for_appointments():
    with SB(
            chromium_arg="--force-device-scale-factor=1",  # Needed to set window size
            browser="chrome",  # When running brave, leave it as chrome. Invokes chromedriver with default options
            # binary_location="/usr/bin/brave-browser",  # Uncomment for Brave Browser
            headed=True,  # Run tests in headed/GUI mode on Linux. (To have access to browser after)
            uc=True,  # Use undetected-chromedriver to evade bot-detection. Only works for Chrome/Brave
            use_auto_ext=False,  # Hide chrome's automation extension
            slow=True,  # Makes actions run slower
            incognito=True, # Enable Chromium's Incognito mode. Clear session cookies
    ) as sb:
        try:  # Clicking logic to get to appointment status
            set_random_window_size(sb)  # Adjust the browser window size (to avoid rate-limiting)
            sb.open(config['url'])  # Fetches values.json
            sb.click("#form")
            sb.select_option_by_text("#form", "Barcelona")
            sb.click("#btnAceptar")
            sb.select_option_by_text("#tramiteGrupo\\[0\\]", config['tramiteOptionText'])  # Fetches values.json
            sb.click("#btnAceptar")
            sb.click("#btnEntrar")
            sb.type("#txtIdCitado", config['idCitadoValue'])  # Fetches values.json
            sb.type("#txtDesCitado", config['desCitadoValue'])  # Fetches values.json
            sb.select_option_by_text("#txtPaisNac", config['paisNacValue'])  # Fetches values.json
            sb.click("#btnEnviar")
            sb.click("#btnEnviar")

            # Checking for appointment availability
            if sb.is_text_visible("En este momento no hay citas disponibles.",
                                  "div.mf-main--content.ac-custom-content p"):
                logging.info("No available appointments. Trying again in 10 minutes.")
                return "retry"
            else:
                # If the text is not found, assume an appointment is available
                sb.set_window_size(1280, 1024)  # Set correct resolution for screenshot
                sb.save_screenshot("/tmp/cita_disponible.png")  # Take a screenshot for the email attachment
                send_email("Cita Disponible Alert", "VNC to vnc://127.0.0.1:5900 to complete", attach_screenshot=True)
                logging.info("Appointments might be available. Keeping the browser open for manual check.")
                user_input = input("Type 'restart' and enter")
                if user_input.lower() == "restart": # SB Context manager quits automatically. workaround to maintain open
                    return "manual_check_needed"

        except Exception as e:
            logging.error(f"Encountered an error during the steps: {e}. Trying again in 10 minutes.")
            return "error"


#  Test retry logic
def main():
    setup_logging()  # Enable logs at /tmp/events.log
    while True:
        result = check_for_appointments()
        if result == "retry" or result == "error":
            time.sleep(600)  # Retry every 10 minutes
        elif result == "manual_check_needed":  # Placeholder. try loop never gets here (keep open relies on user input)
            input("Press Enter to exit after your manual check...")
            break  # Exit the loop and end the script


if __name__ == "__main__":
    main()
