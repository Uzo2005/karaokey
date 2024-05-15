import os
import sys
from azure.storage.blob import BlobServiceClient

with open('.env', 'r') as fh:
    envVariables = dict(tuple(line.replace('\n', '').split('=', 1)
        for line in fh.readlines() if not line.startswith('#') and len(line.strip()) > 0))
    

argc = len(sys.argv)
fileName = ""

for i in range(1, argc):
    value = sys.argv[i].split("=", 1)[1].strip()
    match sys.argv[i].split("=", 1)[0].strip():
        case "--file":
            fileName = value

accName = envVariables['STORAGE_ACCOUNT_NAME'].strip()
accKey = envVariables['STORAGE_ACCOUNT_KEY']
service = BlobServiceClient.from_connection_string(f"DefaultEndpointsProtocol=https;AccountName={accName};AccountKey={accKey};EndpointSuffix=core.windows.net")


def upload_blob_file(blob_service_client: BlobServiceClient, fileName: str, container_name: str):
    container_client = blob_service_client.get_container_client(container=container_name)
    with open(file=os.path.join('./fileBucket', fileName), mode="rb") as data:
        blob_client = container_client.upload_blob(name=fileName, data=data, overwrite=True, connection_timeout=600)
        # print(blob_client)

upload_blob_file(blob_service_client=service, fileName=fileName, container_name="karaokey")
