#!/usr/bin/env python3

from io import BytesIO
import base64, base58, varint, os, json
# from lib.cesium import CesiumPlus as cs

## BytesIO adds a stream interface to bytes
## Exemple:
qr = BytesIO(bytes.fromhex("8316140212c28e52e034ecaf684fa3e5d755db519074f27ad086bddffd26b386e55f3b623ca01f0177c0f8ce5f6a69764c7bc10263ec"))

## Read from a file:
# qr = open("qrcode-AXfA-M5faml2THvBAmPs.bin","rb")
# qr = BytesIO(qr.read())

## Check magic number
assert qr.read(3) == b"\x83\x16\x14"

## Read data type
data_type = varint.decode_stream(qr)

## Read price type
raw_price_type = varint.decode_stream(qr)
price_type = raw_price_type >> 4
amount_len = raw_price_type & 0b1111

## Read pubkey
pubkey = qr.read(32)
pubkey_b58 = base58.b58encode(pubkey)
# print("Pubkey: {}".format(pubkey_b58.decode("utf-8")))

## Read amount

if price_type == 0: # Free price, ignore amount
    qr.read(amount_len)
    print("Free price")

elif price_type == 1: # Units
    amount = varint.decode_stream(qr)
    # print("Price: {} Ğ1".format(amount/100))

elif price_type == 2: # UD
    amount_n = varint.decode_stream(qr)
    amount_e = varint.decode_stream(qr)
    amount = amount_n * 10 ** -amount_e
    # print("Price: {} UD_Ğ1".format(amount.decode("utf-8")))

else:
    qr.read(amount_len)
    print("Error: unknown price type, ignoring price")

## Read data

if data_type == 0: # No data
    data = None
    print("There is no data")

elif data_type == 1: # Plain text
    data = qr.read()
    print("Data:")
    print(data)

elif data_type == 2: # Ğchange ad
    data = base64.urlsafe_b64encode(qr.read(16))
    # print("Ğchange ad ID: {}".format(data.decode("utf-8")))
  
    
## Get gchange-pod datas

item = os.popen("./../jaklis/jaklis.py getoffer -i {0}".format(data.decode("utf-8")))
# item = cs.getOffer(id)


jsonR = json.load(item)
item_time = jsonR['creationTime']
item_name = jsonR['title']
item_description = jsonR['description']
item_image = jsonR['thumbnail']
isImage = '_content' in item_image
if (isImage):
    print(item_image['_content'])

# print(jsonR)
print(item_time)
print(item_name)
print(item_description)

