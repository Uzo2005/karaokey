#!/bin/bash

set -xe

pip install azure-storage-blob
pip install gradio_client
pip install azure-cognitiveservices-speech
pip install mutagen

python -m pip install git+https://zotify.xyz/zotify/zotify.git 

nimble install

set +x
echo "REMEBER TO SETUP ZOTIFY WITH YOUR SPOTIFY CREDENTIALS"
echo "REMEMBER TO INSTALL libopenssl 1.1 to workaround the azure bug"



