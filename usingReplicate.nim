#####
#NOT USING REPLICATE AGAIN BECAUSE STRIPE IS REJECTING NIGERIAN CREDIT CARDS
####

# import std/[httpclient, uri, asyncdispatch, parsecfg, strformat, json, strutils]
# import chronicles

# const BaseUrl = "https://api.replicate.com/v1"

# let
#     cfg = loadConfig(".env")
#     apiKey = cfg.getSectionValue("", "REPLICATE_APIKEY")
#     modelVersion = cfg.getSectionValue("", "Model_Version")
#     defaultHeaders = newHttpHeaders({"Authorization": fmt"Bearer {apiKey}"})

# let client = newAsyncHttpClient()
# client.headers = defaultHeaders

# proc uploadSong(
#         httpClient: AsyncHttpClient, songFileName: string
# ): Future[string] {.async.} =
#     httpClient.headers["Content-Type"] = "multipart/form-data"

#     try:
#         let data = newMultipartData()
#         data["content"] = (
#             name: songFileName,
#             contentType: "application/octet-stream",
#             content: readfile(songFileName),
#         )

#         let response = await client.post(fmt"{BaseUrl}/files", multipart = data)
#         result = $(parseJson(await response.body)["urls"]["get"])
#     except Exception as e:
#         fatal "Exception Occured", name = e.name, msg = e.msg

# proc getPredictions(
#         httpClient: AsyncHttpClient, songUrl: string
# ): Future[string] {.async.} =
#     httpClient.headers["Content-Type"] = "application/json"

#     try:
#         # let
#         #     body = parseJson fmt(
#         #         """
#         #             {
#         #                 "version": "<modelVersion>",
#         #                 "input": {
#         #                     "sonify": true,
#         #                     "visualize": true,
#         #                     "music_input": "<songUrl>",
#         #                     "audioSeperator": true
#         #                 }
#         #             }
#         #         """,
#         #         '<', '>',
#         #     )

#         #     response = await httpClient.postContent(fmt"{BaseUrl}/predictions", body = $body)

#         #     predictionUrl = unescape $(parseJson(response)["urls"]["get"])
#         let predictionUrl =
#             "https://api.replicate.com/v1/predictions/32mwmt7y89rgg0cfbdkrh606mm"

#         while true:
#             let currentStatus = unescape $(parseJson(await httpClient.getContent(predictionUrl))["status"])

#             case currentStatus:
#                 of "succeeded":
#                     break
#                 of "failed", "cancelled":
#                     error "Prediction Failed", song = songUrl
#                     raise newException(ValueError, "Prediction Failed")
#                 else:
#                     echo "Current Status is ", $(result.parseJson["status"])
#                     await sleepAsync(3000)

#         result = await httpClient.getContent(predictionUrl)

#     except Exception as e:
#         fatal "Exception Occured", name = e.name, msg = e.msg

# iterator pollUntilEnd(urls: openArray[string]): string =
#     discard

# let
#     # url = waitfor client.uploadSong("shop_vac.mp3")
#     url =
#         "https://api.replicate.com/v1/files/NDgxZmVkNTUtMmI5Ny00OTdmLTg2NjAtNDQzNWYzNDc4OWNl"
#     predictions = waitfor client.getPredictions(url)

# echo predictions
