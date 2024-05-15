from mutagen.mp3 import MP3
from mutagen.wavpack import WavPack
import sys, json

argc = len(sys.argv)
fileName = ""
fileFormat = ""

for i in range(1, argc):
    value = sys.argv[i].split("=", 1)[1].strip()
    match sys.argv[i].split("=", 1)[0].strip():
        case "--file":
            fileName = value
        case "--format":
            fileFormat = value

audioInfo = {}
match fileFormat:
    case "mp3":
        audio = MP3("fileBucket/"+fileName)
        audioInfo = {"title": audio["TIT2"].text[0], "artist": audio["TPE1"].text[0], "album": audio["TALB"].text[0], "duration": audio.info.length}
    case "wav":
        audio = WavPack("fileBucket/"+fileName)
        audioInfo = {"title": audio["title"].text[0], "artist": audio["artist"].text[0], "album": audio["album"].text[0], "duration": audio.info.length}

if len(audioInfo) > 0:
    print(json.dumps(audioInfo))
else:
    print(json.dumps({}))