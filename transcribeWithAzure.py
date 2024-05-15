import time
import os
import sys
import azure.cognitiveservices.speech as speechsdk

with open('.env', 'r') as fh:
    envVariables = dict(tuple(line.replace('\n', '').split('=', 1)
        for line in fh.readlines() if not line.startswith('#') and len(line.strip()) > 0))
    

argc = len(sys.argv)
inputFile = ""

for i in range(1, argc):
    value = sys.argv[i].split("=", 1)[1].strip()
    match sys.argv[i].split("=", 1)[0].strip():
        case "--infile":
            inputFile = value


key = envVariables["AZURE_SPEECH_KEY"]
region = envVariables["AZURE_SPEECH_REGION"]

speech_config = speechsdk.SpeechConfig(subscription=key, region=region)
speech_config.request_word_level_timestamps()
# speech_config.output_format = speechsdk.OutputFormat(1)

audio_config = speechsdk.audio.AudioConfig(filename=inputFile)
speech_recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config)
done = False

textOut = ""
def stop_cb(evt):
    speech_recognizer.stop_continuous_recognition()
    global done
    done = True

str_newLine = " \n"

def outPrint(evt):
    tmp_text = evt.result.text
    # print(tmp_text)
    global textOut
    textOut += tmp_text + str_newLine

speech_recognizer.recognized.connect(outPrint)
speech_recognizer.session_stopped.connect(stop_cb)
speech_recognizer.start_continuous_recognition()

while not done:
    time.sleep(.5)

print(textOut)

