#!/usr/bin/env bash

set -e

function trap_errors() {
  echo ""
  echo "Debbuging:"
  echo "  pwd:      $(pwd)"
  echo "  MAIN_DIR: ${MAIN_DIR}"
  clean_on_exit
}

trap trap_errors ERR

MAIN_DIR=~/.zen/FR
mkdir -p ~/.zen/FR

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/109.0"

cd "${MAIN_DIR}"

echo -n "Creating directories..."
TMP_DIR=$(mktemp -d)
mkdir -p "${MAIN_DIR}/data/"
mkdir -p "data/gen/an/images/"
echo " done."


if [[ ! -s "${MAIN_DIR}/data/an.zip" ]]; then
    echo -n "Downloading data..."
    wget -q -U "${USER_AGENT}" "https://data.assemblee-nationale.fr/static/openData/repository/16/amo/deputes_actifs_mandats_actifs_organes/AMO10_deputes_actifs_mandats_actifs_organes.json.zip" -O "${MAIN_DIR}/data/an.zip"
    cd "${MAIN_DIR}/data/"
    echo " done."

    echo -n "Extracting data..."
    unzip an.zip
    echo " done. "
fi

cd "${MAIN_DIR}/data/"

find json/acteur/ -type f | sed 's/\.json//i' | sed 's/json\/acteur\///i' | while read -r key; do
  echo -n "Parsing ${key}"

  first_name=$(jq -r .acteur.etatCivil.ident.prenom "json/acteur/${key}.json")
  echo -n " (${first_name} "
  last_name=$(jq -r .acteur.etatCivil.ident.nom "json/acteur/${key}.json")
  echo "${last_name})"

  email=$(jq -r '.acteur.adresses.adresse | map(. | select(.type=="15")) | .[].valElec' "json/acteur/${key}.json" | tac | awk '{print tolower($0)}')
  phoneRaw=$(jq -r '.acteur.adresses.adresse | map(. | select(.type=="11")) | .[].valElec' "json/acteur/${key}.json" | tac)

  IFS=$'\n'
  phone=""
  if [ ! -z "$phoneRaw" ]; then
    for i in $phoneRaw; do
      phone="$(echo ${i} | tr -d ' .' | sed 's/(0)//i' | sed 's/^00/\+/i' | sed 's/^0590/\+590/i' | sed 's/^0596/\+596/i' | sed 's/^0594/\+594/i' | sed 's/^0262/\+262/i' | sed 's/^0508/\+508/i' | sed 's/^0269/\+262269/i' )"$'\n'"${phone}"
    done
  fi

  phonesChamber=$(jq -r "map(select(.name==\"${first_name} ${last_name}\")) | .[].phone" "json/acteur/${key}.json" | tr -d ' .' 2>/dev/null)

  if [ ! -z "$phonesChamber" ]; then
    for i in $phonesChamber; do
      phone=$(echo "${phone}" | sed "s/${i}//g" | sort -u)
      phone="${i}"$'\n'"${phone}"
    done
  fi

  twitter=$(jq -r '.acteur.adresses.adresse | map(. | select(.type=="24")) | .[].valElec' "json/acteur/${key}.json" | sed 's/\@//i')
  facebook=$(jq -r '.acteur.adresses.adresse | map(. | select(.type=="25")) | .[].valElec' "json/acteur/${key}.json" | sed 's/\@//i')

  commissionsRef=$(jq -r '.acteur.mandats[] | map(. | select(.typeOrgane=="COMPER" or .typeOrgane=="COMNL")) | .[].organes.organeRef' "json/acteur/${key}.json" | sort -u)

  commissions=""
  if [ ! -z "$commissionsRef" ]; then
    for i in $commissionsRef; do
      commissions="${commissions}"$'\n'"$(jq -r .organe.libelleAbrege json/organe/${i}.json)"
    done
  fi

  county=$(jq -r '.acteur.mandats[] | map(. | select(.typeOrgane=="ASSEMBLEE")) | .[].election.lieu.departement' "json/acteur/${key}.json" | head -1)

  groupRef=$(jq -r '.acteur.mandats[] | map(. | select(.typeOrgane=="GP")) | .[].organes.organeRef' "json/acteur/${key}.json" | head -1)
  group=$(jq -r .organe.libelle json/organe/${groupRef}.json)

  photo=$(echo ${key} | sed 's/PA//i')

  filename="${MAIN_DIR}/data/${key}.yml"

[[ -s ${filename} ]] && cat "${filename}" && continue

  echo -n "  Writing data..."
  echo "id: ${key}" > "${filename}"
  echo "last_name: ${last_name}" >> "${filename}"
  echo "first_name: ${first_name}" >> "${filename}"
  echo "group: ${group}" >> "${filename}"
  echo "county: ${county}" >> "${filename}"

  echo "commissions:" >> "${filename}"
  if [ ! -z "${commissions}" ]; then
    for i in ${commissions}; do
      echo "- \"${i}\"" >> "${filename}"
    done
  fi

  echo -n "phone:" >> "${filename}"
  if [ ! -z "${phone}" ]; then
    echo "" >> "${filename}"
    for i in ${phone}; do
      echo "- \"${i}\"" >> "${filename}"
    done
  else
    echo " \"\"" >> "${filename}"
  fi

  echo "email:" >> "${filename}"
  if [ ! -z "${email}" ]; then
    for i in ${email}; do
      echo "- \"${i}\"" >> "${filename}"
    done
  fi

  echo "twitter: ${twitter}" >> "${filename}"
  echo "facebook: ${facebook}" >> "${filename}"
  echo "photo: ${photo}" >> "${filename}"

  echo " done."

  echo -n "  Downloading photo..."
  if [ ! -f "${MAIN_DIR}/data/gen/an/images/${photo}.jpg" ]; then
    wget -q -U "${USER_AGENT}" "https://www2.assemblee-nationale.fr/static/tribun/16/photos/${photo}.jpg" -O "${MAIN_DIR}/data/gen/an/images/${photo}.jpg"
  fi
  echo " done."

 cat "${filename}"

CUR=5
WHAT=${RANDOM:0:1}
echo "sleeping $((CUR+WHAT))"
sleep $((CUR+WHAT))

done
