import std/[json, os, osproc, strformat, strutils, httpclient, asyncdispatch, uri]
import pkg/[prologue, prologue/middlewares/staticFile, chronicles, checksums/sha1]
import ./db_utils

when defined(release):
    let port = Port(80)
else:
    let port = Port(2005)

template logGoodUpdate(songId, updateStr: string) =
    info "UPDATE: ", msg = updateStr
    update(songId, updateStr)

template logBadUpdate(songId, updateStr: string) =
    error "ERROR: ", msg = updateStr
    update(songId, "ERROR: " & updateStr & ". Aborting any further processing for this audio.")
    raise newException(
        IOError, "something went wrong while processing song <" & songId & ">"
    )

template processSong() {.dirty.} =
    songId.logGoodUpdate(
        fmt"Extracting Information About Song With id: <{songId}> From Downloaded Audio"
    )
    var (infoResult, exitCode) =
        execCmdEx(fmt"python getAudioInfo.py --file={fileName} --format={format}")

    if exitCode != 0:
        songId.logGoodUpdate(
            fmt"Could Not Get Any Info About Song With id: <{songId}> From Downloaded File"
        )

        # songId.logBadUpdate(
        #     "Something went wrong while trying to get the audio information from the file"
        # )

    let songInfo =
        try:
            parseJson infoResult
        except:
            %*{}

    if songInfo.len > 0:
        if songInfo.hasKey("title") and (($songInfo["title"]).len != 0):
            songTitle = unescape $songInfo["title"]
            songId.logGoodUpdate("Song Title = " & songTitle)
        else:
            songId.logGoodUpdate(
                fmt"Song With id: <{songId}> Title Not Found Inside File"
            )

        if songInfo.hasKey("artist") and (($songInfo["artist"]).len != 0):
            artistName = unescape $songInfo["artist"]
            songId.logGoodUpdate("Artist = " & artistName)
        else:
            songId.logGoodUpdate(
                fmt"Artist Name for song With id: <{songId}> Not Found Inside File"
            )

        if songInfo.hasKey("album") and (($songInfo["album"]).len != 0):
            songAlbum = unescape $songInfo["album"]
            songId.logGoodUpdate("Song Album = " & songAlbum)
        else:
            songId.logGoodUpdate(
                fmt"Song With id: <{songId}> Album Not Found Inside File"
            )

        if songInfo.hasKey("duration") and (parseFloat($songInfo["duration"]) != 0.0):
            songDuration = parseFloat($songInfo["duration"])
            songId.logGoodUpdate("Song Duration = " & $songDuration)
        else:
            songId.logGoodUpdate(
                fmt"Song With id: <{songId}> Duration Not Found For Some Reason"
            )
    else:
        songId.logGoodUpdate(
            fmt"Could Not Get Any Info About Song With id: <{songId}> From Downloaded File"
        )

    songId.logGoodUpdate(
        fmt"Uploading downloaded song with id: <{songId}> to azure cloud storage for easier access to everyone"
    )
    let azureUploadExitCode =
        execShellCmd(fmt"python uploadToAzure.py --file={fileName}")

    if azureUploadExitCode == 0:
        songId.logGoodUpdate(
            fmt"Finished Uploading Song With id: <{songId}> to azure cloud storage, access url is https://claypantfilebucket.blob.core.windows.net/karaokey/{fileName}"
        )
    else:
        songId.logBadUpdate(
            fmt"Couldnt upload song With id: <{songId}> to azure cloud storage for some reason"
        )

    songId.logGoodUpdate(
        fmt"Sent audio With id: <{songId}> to mdx-net AI Model on Huggingface spaces at url: https://huggingface.co/spaces/r3gm/Audio_separator" &
            " to extract the voice track from the background track, currently waiting for the result..."
    )

    let gradioUploadResult =
        try:
            execProcess(fmt"python extractWithGradio.py --file={fileName}").parseJson
        except:
            %*{}

    if gradioUploadResult.len == 2:
        songId.logGoodUpdate(
            fmt"Done extracting the voice track from the background track for song With id: <{songId}> using https://huggingface.co/spaces/r3gm/Audio_separator"
        )
    else:
        songId.logBadUpdate(
            fmt"The mdx-net AI model failed to extract the voice track from the background track for song With id: <{songId}>. Aborting any further processing steps for this audio"
        )

    let
        vocalTrackPath = unescape $gradioUploadResult[0]
        backgroundTrackPath = unescape $gradioUploadResult[1]

    songId.logGoodUpdate(
        fmt"Obtaining Song Lyrics for song With id: <{songId}> By Either Using https://lrclib.net Lyrics API or Transcribing The Vocal Track"
    )
    let songLyricsStr = getSongLyrics(songTitle, artistName, songAlbum, songDuration)
    if songLyricsStr.len > 0:
        songId.logGoodUpdate(
            fmt"Song Lyrics for song With id: <{songId}> Has Been Obtained From https://lrclib.net Lyrics api"
        )
        let songLyrics = parseJson(songLyricsStr)
        if songLyrics.hasKey("syncedLyrics"):
            lyrics = $songLyrics["syncedLyrics"]
            isSyncedLyrics = true
            songId.logGoodUpdate(
                fmt"Song Lyrics for song With id: <{songId}> Are In A Synced Format! Say yay to better user experience!!"
            )
        else:
            lyrics = $songLyrics["plainLyrics"]
    else:
        songId.logGoodUpdate(
            fmt"https://lrclib.net Lyrics api doesnt have the song lyrics for song With id: <{songId}>, moving on to using the azure speech service"
        )
        let songLyrics =
            execProcess(fmt"python transcribeWithAzure.py --infile={vocalTrackPath}")

        if songLyrics.len > 0:
            lyrics = songLyrics
            songId.logGoodUpdate(
                fmt"Song Lyrics Has Been Obtained From Azure Speech Service By Transcribing Vocal Track for song With id: <{songId}>"
            )
        else:
            songId.logGoodUpdate(
                fmt"ERROR: Song Lyrics Could Not Be Obtained From Azure Speech Service for song With id: <{songId}>"
            )

    songId.logGoodUpdate(
        fmt"Sending processed audio files for song With id: <{songId}> to the client..."
    )

    let processedSong =
        %*{
            "isSyncedLyrics": isSyncedLyrics,
            "lyrics": lyrics,
            "vocalTrackUrl":
                fmt"https://r3gm-audio-separator.hf.space/file={vocalTrackPath}",
            "backgroundTrackUrl":
                fmt"https://r3gm-audio-separator.hf.space/file={backgroundTrackPath}",
        }

proc getSongLyrics(title, artist, album: string, duration: float): string =
    let lrcLibUrl =
        parseUri("https://lrclib.net/api/get") ? {
            "track_name": title,
            "artist_name": artist,
            "album_name": album,
            "duration": $duration,
        }
    var client = newHttpClient()
    let response = client.get(lrcLibUrl)

    if response.status.contains("200"):
        result = response.body

proc getIndexPage(ctx: Context) {.async, gcsafe.} =
    let indexPage = readfile("index.html")
    resp indexPage

proc getSpotifySong(ctx: Context) {.async, gcsafe.} =
    try:
        let
            songUrl = unescape $(parseJson(ctx.request.body)["songUrl"])
            songId = ($secureHash(songUrl)).toLowerAscii
            fileName = songId & ".mp3"
            format = ".mp3"

        var
            songTitle, artistName, songAlbum: string
            songDuration: float
            lyrics: string
            isSyncedLyrics: bool

        songId.logGoodUpdate("Downloading Song With Url: " & songUrl)
        let downloadExitCode = execShellCmd(
            fmt"zotify {songUrl} --root-path=fileBucket --root-podcast-path=fileBucket --download-lyrics=false --download-format=mp3 --download-quality=very_high --print-download-progress=false  --print-downloads=true --output={fileName}"
        )
        if downloadExitCode == 0:
            songId.logGoodUpdate("Finished Downloading Song With Url: " & songUrl)
        else:
            songId.logBadUpdate(
                "Downloading Song With Url: " & songUrl & " Failed For Some Reason"
            )

        processSong()

        discard execShellCmd("echo " & $processedSong & " >> resultsDump.txt")
        resp $processedSong
        songId.resetUpdates()
    except Exception as e:
        resp $["Error: " & e.msg]
        error "Exception Occured: ", msg = e.msg, procedure = "getSpotifySong"

proc processUserUploadedSong(ctx: Context) {.async, gcsafe.} =
    try:
        let
            song = ctx.getUploadFile("song")
            songId = ($secureHash(song.body)).toLowerAscii
            format = song.fileName.splitFile.ext[1 ..^ 1]
            fileName = songId & "." & format
        song.save("fileBucket", fileName)

        var
            songTitle, artistName, songAlbum: string
            songDuration: float
            lyrics: string
            isSyncedLyrics: bool

        processSong()

        discard execShellCmd("echo " & $processedSong & " >> resultsDump.txt")
        # echo processedSong
        resp $processedSong
        songId.resetUpdates()
    except Exception as e:
        resp $["Error: " & e.msg]
        error "Exception Occured: ", msg = e.msg, procedure = "processUserUploadedSong"

proc sendUpdates(ctx: Context) {.async, gcsafe.} =
    try:
        ctx.response.setHeader("Content-Type", "text/event-stream")
        ctx.response.setHeader("Cache-Control", "no-cache")
        ctx.response.setHeader("Connection", "keep-alive")

        let
            id = ctx.getPathParams("id").toLowerAscii
            event = "message"
            data = %*getUpdates(id)

        resp &"event: {event}\ndata: {$data}\n\n"
    except Exception as e:
        error "Exception Occured: ", msg = e.msg, procedure = "sendUpdates"

let settings = newSettings(port = port)
var app = newApp(settings)

app.get("/", getIndexPage)
app.post("/spotifySong", getSpotifySong)
app.post("/uploadAudio", processUserUploadedSong)
app.get("/update/{id}", sendUpdates)

app.use(staticFileMiddleware("public"))
app.run()
