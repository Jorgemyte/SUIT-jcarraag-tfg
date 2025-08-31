import os
import time
import json
import boto3
import random
import string
import urllib.request
import urllib.error
import traceback
import subprocess
from datetime import datetime
from selenium import webdriver
from pyvirtualdisplay.display import Display
from botocore.exceptions import ClientError
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.firefox.service import Service as FirefoxService

br = os.environ['BROWSER'].lower()
br_version = os.environ['BROWSER_VERSION']
driver_version = os.environ['DRIVER_VERSION']

s3 = boto3.client('s3')
ddb = boto3.client('dynamodb')
sfn = boto3.client('stepfunctions')
enable_display = False

if 'DISPLAY' in os.environ and os.environ['DISPLAY'] == ':25':
    enable_display = True

if enable_display:
    display = Display(visible=False, extra_args=[':25'], size=(2560, 1440)) 
    display.start()
    print('Started Display %s' % os.environ['DISPLAY'])

if br == 'firefox':
    firefox_options = FirefoxOptions()
    if not enable_display:
        firefox_options.add_argument("-headless")
    #firefox_options.add_argument("-safe-mode")
    firefox_options.add_argument("--no-sandbox")
    firefox_options.add_argument("--disable-dev-shm-usage")
    firefox_options.add_argument("--disable-gpu")
    firefox_options.add_argument("--width=2560")
    firefox_options.add_argument("--height=1440")

    # Crear perfil temporal como antes
    random_dir = '/tmp/' + ''.join(random.choice(string.ascii_lowercase) for i in range(8))
    os.mkdir(random_dir)
    os.chmod(random_dir, 0o755)
    firefox_options.set_preference("profile", random_dir)

    firefox_options.binary_location = f'/opt/firefox/{br_version}/firefox'
    service = FirefoxService(executable_path=f'/opt/geckodriver/{driver_version}/geckodriver',
                             log_path='/tmp/geckodriver.log')
    driver = webdriver.Firefox(service=service, options=firefox_options)
    print('Started Firefox Driver')

elif br == 'chrome':
    chrome_options = ChromeOptions()
    if not enable_display:
        chrome_options.add_argument('--headless')
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--disable-dev-tools")
    chrome_options.add_argument("--no-zygote")
    chrome_options.add_argument("--single-process")
    chrome_options.add_argument("window-size=2560x1440")
    chrome_options.add_argument("--user-data-dir=/tmp/chrome-user-data")
    chrome_options.add_argument("--remote-debugging-port=9222")
    chrome_options.binary_location = f'/opt/chrome/{br_version}/chrome'

    service = ChromeService(executable_path=f'/opt/chromedriver/{driver_version}/chromedriver',
                            log_path='/tmp/chromedriver.log')
    driver = webdriver.Chrome(service=service, options=chrome_options)
    print('Started Chrome Driver')

else:
    print('Unsupported browser %s' % br)

def funcname():
    import inspect
    return inspect.stack()[1].function  # Más legible y moderno

def update_status(mod, tc, st, et, ss, er, trun, status_table):
    t_t  =  ' '    #  valor  por  defecto
    key  =  {
            'testrunid':  {'S':  trun},
            'testcaseid':  {'S':  f"{mod}-{br}_{br_version}-{tc}"}
    }
    try:
        if et.strip():
            start_dt = datetime.strptime(st, '%d-%m-%Y %H:%M:%S,%f')
            end_dt = datetime.strptime(et, '%d-%m-%Y %H:%M:%S,%f')
            t_t = str(int(round((end_dt - start_dt).total_seconds() * 1000, -3)))
        else:
            t_t = ' '

        key = {
            'testrunid': {'S': trun},
            'testcaseid': {'S': f"{mod}-{br}_{br_version}-{tc}"}
        }

        if er:
            update_expr = (
                "SET details.StartTime = :st, details.EndTime = :e, details.#S = :s, "
                "details.ErrorMessage = :er, details.TimeTaken = :tt"
            )
            expr_values = {
                ':st': {'S': st},
                ':e': {'S': et},
                ':s': {'S': ss},
                ':er': {'S': er},
                ':tt': {'S': t_t}
            }
        else:
            update_expr = (
                "SET details.StartTime = :st, details.EndTime = :e, details.#S = :s, "
                "details.TimeTaken = :tt"
            )
            expr_values = {
                ':st': {'S': st},
                ':e': {'S': et},
                ':s': {'S': ss},
                ':tt': {'S': t_t}
            }

        ddb.update_item(
            TableName=status_table,
            Key=key,
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames={'#S': 'Status'}
        )

    except ClientError as e:
        if e.response['Error']['Code'] == 'ValidationException':
            ddb.update_item(
                TableName=status_table,
                Key=key,
                UpdateExpression="SET #atName = :atValue",
                ExpressionAttributeValues={
                    ':atValue': {
                        'M': {
                            'StartTime': {'S': st},
                            'EndTime': {'S': et},
                            'Status': {'S': ss},
                            'ErrorMessage': {'S': er},
                            'TimeTaken': {'S': t_t}
                        }
                    }
                },
                ExpressionAttributeNames={'#atName': 'details'}
            )
        else:
            traceback.print_exc()
    except Exception:
        traceback.print_exc()

def tc0001(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))

        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        print(f'Completed test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)

        return {"status": "Success", "message": "Successfully executed TC0001"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)

        return {"status": "Failed", "message": "Failed to execute TC0001. Check logs for details."}


def tc0002(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '
    todisplay = (
        'Serverless is a way to describe the services, practices, and strategies '
        'that enable you to build more agile applications so you can innovate and '
        'respond to change faster.'
    )

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='bc']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'displaybtn')))
        assert 'Serverless UI Testing - Button Click.' in browser.title
        browser.find_element(By.ID, 'displaybtn').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbutton')))
        displayed = browser.find_element(By.ID, 'cbbutton').text

        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        print(f'Completed test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')

        if todisplay == displayed:
            update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
            return {"status": "Success", "message": "Successfully executed TC0002"}
        else:
            update_status(mod, tc, starttime, endtime, 'Failed',
                          "Expected text not displayed.", trun, status_table)
            return {"status": "Failed", "message": "Failed to execute TC0002. Check logs for details."}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0002. Check logs for details."}

def tc0011(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    recorder = None
    try:
        if enable_display:
            filepath = '/tmp/'
            recorder = subprocess.Popen([
                '/usr/bin/ffmpeg', '-f', 'x11grab', '-video_size', '2560x1440',
                '-framerate', '25', '-probesize', '10M', '-i', ':25',
                '-y', filepath + 'tc0011.mp4'
            ])
            time.sleep(0.5)

        print('Getting URL')
        starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        endtime = ' '
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        def navigate_and_assert(title, element_id=None, xpath=None, name=None, click_id=None):
            browser.get(main_url)
            assert 'Serverless UI Testing' in browser.title
            WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
            if xpath:
                browser.find_element(By.XPATH, xpath).click()
            if click_id:
                browser.find_element(By.ID, click_id).click()
            if name:
                WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.NAME, name)))
            if element_id:
                WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, element_id)))
            assert title in browser.title

        navigate_and_assert('Serverless UI Testing - Button Click.', xpath="//*[@id='bc']/a", element_id='displaybtn')
        browser.find_element(By.ID, 'displaybtn').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbutton')))

        navigate_and_assert('Serverless UI Testing - Check Box.', xpath="//*[@id='cb']/a", element_id='box3')
        browser.find_element(By.ID, 'box1').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbox1')))

        navigate_and_assert('Serverless UI Testing - Dropdown', xpath="//*[@id='dd']/a", name='cbdropdown')
        browser.find_element(By.ID, 'CP').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'dvidrop')))

        navigate_and_assert('Serverless UI Testing - Images', xpath="//*[@id='img']/a", element_id='image1')

        navigate_and_assert('Serverless UI Testing - Key Press.', xpath="//*[@id='kp']/a", element_id='titletext')

        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')

        if enable_display and recorder:
            recorder.terminate()
            time.sleep(7)
            print('Closed recorder')
            recorder.wait(timeout=20)

        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)

        if enable_display:
            try:
                s3.upload_file('/tmp/tc0011.mp4', s3buck, s3prefix + 'tc0011.mp4')
                os.remove('/tmp/tc0011.mp4')
            except Exception:
                traceback.print_exc()
                return {"status": "Failed", "message": "Failed to upload video to S3"}

        return {"status": "Success", "message": "Successfully executed TC0011"}

    except Exception:
        traceback.print_exc()
        try:
            s3.upload_file('/tmp/chromedriver.log', s3buck, s3prefix + 'chromedriver.log')
        except Exception:
            pass
        if recorder:
            recorder.terminate()
        return {"status": "Failed", "message": "Failed to execute TC0011. Check logs for details."}


def tc0003(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='bc']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'displaybtn')))
        assert 'Serverless UI Testing - Button Click.' in browser.title
        browser.find_element(By.ID, 'displaybtn').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbutton')))
        browser.find_element(By.ID, 'resetbtn').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbutton')))
        displayed = browser.find_element(By.ID, 'cbbutton').text

        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        print(f'Completed test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')

        if displayed:
            update_status(mod, tc, starttime, endtime, 'Failed',
                          'Text was not reset as expected.', trun, status_table)
            return {"status": "Failed", "message": "Text was not reset as expected."}
        else:
            update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
            return {"status": "Success", "message": "Successfully executed TC0003"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0003. Check logs for details."}


def tc0004(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='cb']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'box3')))
        assert 'Serverless UI Testing - Check Box.' in browser.title

        browser.find_element(By.ID, 'box1').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbox1')))
        displayed = browser.find_element(By.ID, 'cbbox1').text
        if displayed != 'Checkbox 1 checked.':
            endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
            update_status(mod, tc, starttime, endtime, 'Failed',
                          'Checkbox1 text was not displayed.', trun, status_table)
            return {"status": "Failed", "message": "Checkbox1 text was not displayed."}

        browser.find_element(By.ID, 'box2').click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'cbbox2')))
        displayed = browser.find_element(By.ID, 'cbbox2').text
        if displayed != 'Checkbox 2 checked.':
            endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
            update_status(mod, tc, starttime, endtime, 'Failed',
                          'Checkbox2 text was not displayed.', trun, status_table)
            return {"status": "Failed", "message": "Checkbox2 text was not displayed."}

        browser.find_element(By.ID, 'box1').click()
        WebDriverWait(browser, 20).until_not(EC.visibility_of_element_located((By.ID, 'cbbox1')))
        displayed = browser.find_element(By.ID, 'cbbox1').text
        if displayed:
            endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
            update_status(mod, tc, starttime, endtime, 'Failed',
                          'Checkbox1 text was displayed after unchecking.', trun, status_table)
            return {"status": "Failed", "message": "Checkbox1 text was displayed after unchecking."}

        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        print(f'Completed test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
        return {"status": "Success", "message": "Successfully executed TC0004"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0004. Check logs for details."}


def tc0005(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    dropdown_checks = {
        'CP': 'AWS CodePipeline is a continuous integration and continuous delivery service '
              'for fast and reliable application and infrastructure updates.',
        'CC': 'AWS CodeCommit is a fully-managed source control service that makes it easy for '
              'companies to host secure and highly scalable private Git repositories.',
        'CB': 'AWS CodeBuild is a fully managed build service that compiles source code, '
              'runs tests, and produces software packages that are ready to deploy.',
        'CD': 'AWS CodeDeploy is a service that automates code deployments to any instance, '
              'including Amazon EC2 instances and instances running on-premises.',
        'CS': 'AWS CodeStar enables you to quickly develop, build, and deploy applications on AWS. '
              'AWS CodeStar provides a unified user interface, enabling you to easily manage your '
              'software development activities in one place.'
    }

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='dd']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.NAME, 'cbdropdown')))
        assert 'Serverless UI Testing - Dropdown' in browser.title

        for option_id, expected_text in dropdown_checks.items():
            browser.find_element(By.ID, option_id).click()
            WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'dvidrop')))
            displayed = browser.find_element(By.ID, 'dvidrop').text
            if displayed != expected_text:
                endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
                update_status(mod, tc, starttime, endtime, 'Failed',
                             f'Expected text for {option_id} from dropdown was not displayed.', trun, status_table)
                return {"status": "Failed", "message": f"Expected text for {option_id} from dropdown was not displayed."}

        # Validar opción vacía
        browser.find_element(By.ID, 'emp').click()
        displayed = browser.find_element(By.ID, 'dvidrop').text
        if displayed:
            endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
            update_status(mod, tc, starttime, endtime, 'Failed', 'Expected no text', trun, status_table)
            return {"status": "Failed", "message": "Expected no text."}

        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        print(f'Completed test {funcname()}')
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
        return {"status": "Success", "message": "Successfully executed TC0005"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0005. Check logs for details."}


def tc0006(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='img']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'image1')))
        assert 'Serverless UI Testing - Images' in browser.title

        image_list = browser.find_elements(By.TAG_NAME, 'img')
        for image in image_list:
            imageurl = image.get_attribute('src')
            imgfile = imageurl.split('/')[-1]
            try:
                urllib.request.urlopen(urllib.request.Request(imageurl, method='HEAD'))
            except urllib.error.HTTPError as err:
                if err.code == 403 and imgfile != 'test3.png':
                    endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
                    update_status(mod, tc, starttime, endtime, 'Failed',
                                  'Expected images not displayed.', trun, status_table)
                    return {"status": "Failed", "message": "Expected images not displayed. Check logs for details."}

        print(f'Completed test {funcname()}')
        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
        return {"status": "Success", "message": "Successfully executed TC0006"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0006. Check logs for details."}


def tc0007(browser, mod, tc, s3buck, s3prefix, trun, main_url, status_table):
    fname = f"{mod}-{tc}.png"
    fpath = f"/tmp/{fname}"
    key_pos = [
        Keys.ALT, Keys.CONTROL, Keys.DOWN, Keys.ESCAPE, Keys.F1, Keys.F10, Keys.F11, Keys.F12,
        Keys.F2, Keys.F3, Keys.F4, Keys.F5, Keys.F6, Keys.F7, Keys.F8, Keys.F9,
        Keys.LEFT, Keys.SHIFT, Keys.SPACE, Keys.TAB, Keys.UP
    ]
    key_word = [
        'ALT', 'CONTROL', 'DOWN', 'ESCAPE', 'F1', 'F10', 'F11', 'F12',
        'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9',
        'LEFT', 'SHIFT', 'SPACE', 'TAB', 'UP'
    ]
    starttime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
    endtime = ' '

    try:
        update_status(mod, tc, starttime, endtime, 'Started', ' ', trun, status_table)

        browser.get(main_url)
        assert 'Serverless UI Testing' in browser.title
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'kp')))
        browser.find_element(By.XPATH, "//*[@id='kp']/a").click()
        WebDriverWait(browser, 20).until(EC.visibility_of_element_located((By.ID, 'titletext')))
        assert 'Serverless UI Testing - Key Press.' in browser.title

        actions = webdriver.ActionChains(browser)
        actions.move_to_element(browser.find_element(By.ID, 'titletext')).click()

        rnum = random.randrange(len(key_pos))
        actions.send_keys(key_pos[rnum]).perform()

        WebDriverWait(browser, 5).until(EC.visibility_of_element_located((By.ID, 'keytext')))
        displayed = browser.find_element(By.ID, 'keytext').text
        expected_text = f"You pressed '{key_word[rnum]}' key."

        if displayed != expected_text:
            endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
            update_status(mod, tc, starttime, endtime, 'Failed',
                          'Expected key press not displayed.', trun, status_table)
            return {"status": "Failed", "message": "Expected key press not displayed"}

        print(f'Completed test {funcname()}')
        browser.get_screenshot_as_file(fpath)
        with open(fpath, 'rb') as data:
            s3.upload_fileobj(data, s3buck, s3prefix + fname)
        os.remove(fpath)

        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Passed', ' ', trun, status_table)
        return {"status": "Success", "message": "Successfully executed TC0007"}

    except Exception:
        print(f'Failed while running test {funcname()}')
        traceback.print_exc()
        endtime = datetime.now().strftime('%d-%m-%Y %H:%M:%S,%f')
        update_status(mod, tc, starttime, endtime, 'Failed', traceback.format_exc(), trun, status_table)
        return {"status": "Failed", "message": "Failed to execute TC0007. Check logs for details."}


def lambda_handler(event, context):
    """Lambda Handler"""
    print("Received event:", event)

    tc_name = event.get('tcname')
    browser = driver

    if not browser:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": f"Unsupported browser: {br}"})
        }

    try:
        s3prefix = f"{event['s3prefix']}{event['testrun'].split(':')[-1]}/{br}/"
        testcase_func = globals().get(tc_name)

        if not callable(testcase_func):
            raise ValueError(f"Test case function '{tc_name}' not found.")

        resp = testcase_func(
            browser,
            event['module'],
            tc_name,
            event['s3buck'],
            s3prefix,
            event['testrun'].split(':')[-1],
            event['WebURL'],
            event['StatusTable']
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body":  json.dumps({"message":  resp.get('message',  'No  message returned')  if  isinstance(resp,  dict) else  str(resp)})
        }

    except Exception as e:
        traceback.print_exc()
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": f"Error executing test case: {str(e)}"})
        }

def container_handler():
    """Container Handler"""
    tc_name  = os.environ.get('tcname')
    if  not  tc_name:
        raise  ValueError("Environment  variable  'tcname' is  missing.")
    testcase_func  = globals().get(tc_name)

    browser = driver

    if not browser:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": f"Unsupported browser: {br}"})
        }

    try:
        s3prefix = f"{os.environ['s3prefix']}{os.environ['testrun'].split(':')[-1]}/{br}/"
        testcase_func = globals().get(tc_name)

        if not callable(testcase_func):
            raise ValueError(f"Test case function '{tc_name}' not found.")

        resp = testcase_func(
            browser,
            os.environ['module'],
            tc_name,
            os.environ['s3buck'],
            s3prefix,
            os.environ['testrun'].split(':')[-1],
            os.environ['WebURL'],
            os.environ['StatusTable']
        )

        message  =  resp.get('message', 'No  message  returned') if  isinstance(resp,  dict) else  str(resp)
 
        sfn.send_task_success(
                taskToken=os.environ['TASK_TOKEN_ENV_VARIABLE'],
            output=json.dumps({"message":  message})
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body":  json.dumps({"message":  message})
        }

    except Exception as e:
        traceback.print_exc()
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": f"Error executing test case: {str(e)}"})
        }
   