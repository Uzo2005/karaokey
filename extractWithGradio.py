from gradio_client import Client, file
import json, sys

client = Client("r3gm/Audio_separator", verbose = False)

argc = len(sys.argv)
fileName = ""

for i in range(1, argc):
    value = sys.argv[i].split("=", 1)[1].strip()
    match sys.argv[i].split("=", 1)[0].strip():
        case "--file":
            fileName = value

fileUrl = f"https://claypantfilebucket.blob.core.windows.net/karaokey/{fileName}"
vocals = client.predict(
  media_file=file(fileUrl),
  stem="vocal",
  main=True,
  dereverb=False,
  api_name="/sound_separate"
)

background = client.predict(
  media_file=file(fileUrl),
  stem="background",
  main=True,
  dereverb=False,
  api_name="/sound_separate"
)


print(json.dumps(vocals + background))
