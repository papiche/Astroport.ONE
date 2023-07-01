curl -sX POST 'https://data.gchange.fr/user/profile/_search' -d '{
"_source": [
"title",
"avatar._content_type",
"time",
"address",
"city",
"creationTime",
"description",
"_source.pubkey"
],
"from": 0,
"size": 10,
"sort": {
"creationTime": "desc"
}
}' | jq

