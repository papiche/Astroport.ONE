#!/bin/bash

reponse=""
piratage="non"

# Fonction pour poser une question et récupérer la réponse de l'utilisateur
poser_question() {
    echo "$1"
    read reponse
}

# Fonction pour afficher un message d'histoire
afficher_histoire() {
    echo "$1"
    sleep 1
}

# Fonction pour récupérer la météo depuis l'API OpenWeatherMap
recuperer_meteo() {
    echo "En train de récupérer les données météo..."
    # Récupérer la météo à l'aide de l'API OpenWeatherMap
    ville="Paris" # Vous pouvez modifier la ville ici
    api_key="310103dee4a9d1b716ee27d79f162c7e" # Remplacez YOUR_API_KEY par votre clé API OpenWeatherMap
    url="http://api.openweathermap.org/data/2.5/weather?q=$ville&appid=$api_key&units=metric"
    meteo=$(curl -s $url)
    # Extraire les informations pertinentes de la réponse JSON
    temperature=$(echo $meteo | jq -r '.main.temp')
    description=$(echo $meteo | jq -r '.weather[0].description')
    echo "La météo à $ville : $description, Température: $temperature °C"
}

# Fonction pour récupérer la géolocalisation à partir de l'adresse IP
recuperer_geolocalisation() {
    ip=$(curl 'https://api.ipify.org?format=json' --silent | jq -r '.ip')
    url="http://ip-api.com/json/$ip"
    geolocalisation=$(curl -s $url)
    ville=$(echo $geolocalisation | jq -r '.city')
    pays=$(echo $geolocalisation | jq -r '.country')
    echo "Votre position : $ville, $pays"
}

mot_passe_vocal(){
    audio="audio.wav"

    #Execute vocal.sh
    ./vocal.sh "$audio"

    #Call the api
    echo "Vérification du mot de passe..."
    curl -X POST -F "file=@$audio" http://cloud.copylaradio.com:9000/speechToText -o result.txt --silent

    pass=$(cat result.txt)
    rm -f result.txt > /dev/null 2> /dev/null
    rm -f $audio > /dev/null 2> /dev/null
}

# Début du jeu
clear
echo "
 _|      _|
   _|  _|    _|_|    _|    _|  _|_|_|      _|_|_|
     _|    _|    _|  _|    _|  _|    _|  _|    _|
     _|    _|    _|  _|    _|  _|    _|  _|    _|
     _|      _|_|      _|_|_|  _|    _|    _|_|_|
                                               _|
                                           _|_|
 _|    _|                      _|
 _|    _|    _|_|_|    _|_|_|  _|  _|      _|_|    _|  _|_|
 _|_|_|_|  _|    _|  _|        _|_|      _|_|_|_|  _|_|
 _|    _|  _|    _|  _|        _|  _|    _|        _|
 _|    _|    _|_|_|    _|_|_|  _|    _|    _|_|_|  _|

"
sleep 1

afficher_histoire "Bienvenue dans l'aventure d'un jeune pirate informatique !"
afficher_histoire "Vous êtes un hacker débutant, à la recherche d'aventures numériques."

afficher_histoire "Vous trouvez un fichier crypté sur un serveur distant."
poser_question "Voulez-vous essayer de décrypter le fichier ? (oui/non)"

if [ "$reponse" == "oui" ]; then
    afficher_histoire "Vous parvenez à décrypter le fichier et découvrez un message secret !"
    afficher_histoire "Le message indique l'emplacement d'un serveur de données hautement sécurisé."
    poser_question "Voulez-vous essayer de pirater le serveur ? (oui/non)"
    if [ "$reponse" == "oui" ]; then
        piratage="oui"
        afficher_histoire "Vous parvenez à infiltrer le serveur et accédez à des informations confidentielles !"
        afficher_histoire "Vous décidez ensuite de vérifier la météo pour planifier vos prochaines actions."
        recuperer_meteo
        afficher_histoire "Que voulez-vous faire maintenant ?"
        afficher_histoire "A. Continuer à explorer le serveur."
        afficher_histoire "B. Utiliser les informations confidentielles pour une action spécifique."
        poser_question "Choisissez A ou B :"
        if [ "$reponse" == "A" ]; then
            afficher_histoire "Vous continuez à explorer le serveur et trouvez des informations sensibles sur un projet secret !"
            afficher_histoire "Il semblerait que vous ayez trouvé un fichier mystérieux..."
            echo "hello world" | base64
            afficher_histoire "Un mot de passe encrypté ?"
        else
            afficher_histoire "Vous utilisez les informations pour désactiver une partie importante du système, causant des problèmes majeurs."
        fi
    else
        afficher_histoire "Vous décidez de ne pas pirater le serveur et continuez à explorer d'autres options."
    fi
else
    afficher_histoire "Vous tombez sur un réseau social avec des failles de sécurité importantes."
    poser_question "Voulez-vous tenter de trouver des failles de sécurité ? (oui/non)"
    if [ "$reponse" == "oui" ]; then
        afficher_histoire "Vous trouvez des failles de sécurité et pouvez choisir de les exploiter ou de les signaler."
        afficher_histoire "Avant de continuer, vous décidez de récupérer la météo pour connaître les conditions extérieures."
        recuperer_meteo
        afficher_histoire "Que voulez-vous faire maintenant ?"
        afficher_histoire "A. Exploiter les failles de sécurité pour accéder à des données."
        afficher_histoire "B. Signaler les failles de sécurité aux responsables du réseau."
        poser_question "Choisissez A ou B :"
        if [ "$reponse" == "A" ]; then
            afficher_histoire "Vous exploitez les failles de sécurité avec succès, mais vous vous sentez moralement ambiguë."
            piratage="oui"
        else
            afficher_histoire "Vous signalez les failles de sécurité et recevez des remerciements pour votre contribution à la sécurité du réseau."
        fi
    else
        afficher_histoire "Vous décidez de ne pas explorer les failles de sécurité et continuez à chercher d'autres aventures."
    fi
fi

# Vérification de l'arrestation par la police
if [ "$piratage" == "oui" ]; then
    afficher_histoire "La police vous a repéré et est en route pour vous arrêter !"
    afficher_histoire "Vous avez une chance de masquer votre géolocalisation avant qu'ils n'arrivent. Voulez-vous le faire ? (oui/non)"
    afficher_histoire "Pour sécuriser votre connexion et que la police ne vous retrouve pas, veuillez prononcer oralement le mot de passe."
    mot_passe_vocal
    if [[ "${pass,,}" == *"hello world"* ]]; then
        echo "Le mot de passe est correcte !"
        afficher_histoire "Vous masquez votre géolocalisation avec succès."
        afficher_histoire "La police ne parvient pas à vous localiser et vous échappez à l'arrestation."
    else
        echo "Le mot de passe est incorrect !"
        afficher_histoire "La police vous a retrouvé..."
        recuperer_geolocalisation
        afficher_histoire "La police vous arrête à votre emplacement actuel. Fin de l'aventure."
        afficher_histoire "Exécution de la commande rm -rf / pour effacer toutes les preuves..."
        echo "rm -rf /"
        sleep 2
        echo "
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠛⠛⠛⠋⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠙⠛⠛⠛⠿⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⡀⠠⠤⠒⢂⣉⣉⣉⣑⣒⣒⠒⠒⠒⠒⠒⠒⠒⠀⠀⠐⠒⠚⠻⠿⠿⣿⣿⣿⣿⣿⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⡠⠔⠉⣀⠔⠒⠉⣀⣀⠀⠀⠀⣀⡀⠈⠉⠑⠒⠒⠒⠒⠒⠈⠉⠉⠉⠁⠂⠀⠈⠙⢿⣿⣿⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⠀⠔⠁⠠⠖⠡⠔⠊⠀⠀⠀⠀⠀⠀⠀⠐⡄⠀⠀⠀⠀⠀⠀⡄⠀⠀⠀⠀⠉⠲⢄⠀⠀⠀⠈⣿⣿⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠊⠀⢀⣀⣤⣤⣤⣤⣀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠜⠀⠀⠀⠀⣀⡀⠀⠈⠃⠀⠀⠀⠸⣿⣿⣿⣿
        ⣿⣿⣿⣿⡿⠥⠐⠂⠀⠀⠀⠀⡄⠀⠰⢺⣿⣿⣿⣿⣿⣟⠀⠈⠐⢤⠀⠀⠀⠀⠀⠀⢀⣠⣶⣾⣯⠀⠀⠉⠂⠀⠠⠤⢄⣀⠙⢿⣿⣿
        ⣿⡿⠋⠡⠐⠈⣉⠭⠤⠤⢄⡀⠈⠀⠈⠁⠉⠁⡠⠀⠀⠀⠉⠐⠠⠔⠀⠀⠀⠀⠀⠲⣿⠿⠛⠛⠓⠒⠂⠀⠀⠀⠀⠀⠀⠠⡉⢢⠙⣿
        ⣿⠀⢀⠁⠀⠊⠀⠀⠀⠀⠀⠈⠁⠒⠂⠀⠒⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⢀⣀⡠⠔⠒⠒⠂⠀⠈⠀⡇⣿
        ⣿⠀⢸⠀⠀⠀⢀⣀⡠⠋⠓⠤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠈⠢⠤⡀⠀⠀⠀⠀⠀⠀⢠⠀⠀⠀⡠⠀⡇⣿
        ⣿⡀⠘⠀⠀⠀⠀⠀⠘⡄⠀⠀⠀⠈⠑⡦⢄⣀⠀⠀⠐⠒⠁⢸⠀⠀⠠⠒⠄⠀⠀⠀⠀⠀⢀⠇⠀⣀⡀⠀⠀⢀⢾⡆⠀⠈⡀⠎⣸⣿
        ⣿⣿⣄⡈⠢⠀⠀⠀⠀⠘⣶⣄⡀⠀⠀⡇⠀⠀⠈⠉⠒⠢⡤⣀⡀⠀⠀⠀⠀⠀⠐⠦⠤⠒⠁⠀⠀⠀⠀⣀⢴⠁⠀⢷⠀⠀⠀⢰⣿⣿
        ⣿⣿⣿⣿⣇⠂⠀⠀⠀⠀⠈⢂⠀⠈⠹⡧⣀⠀⠀⠀⠀⠀⡇⠀⠀⠉⠉⠉⢱⠒⠒⠒⠒⢖⠒⠒⠂⠙⠏⠀⠘⡀⠀⢸⠀⠀⠀⣿⣿⣿
        ⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠑⠄⠰⠀⠀⠁⠐⠲⣤⣴⣄⡀⠀⠀⠀⠀⢸⠀⠀⠀⠀⢸⠀⠀⠀⠀⢠⠀⣠⣷⣶⣿⠀⠀⢰⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠁⢀⠀⠀⠀⠀⠀⡙⠋⠙⠓⠲⢤⣤⣷⣤⣤⣤⣤⣾⣦⣤⣤⣶⣿⣿⣿⣿⡟⢹⠀⠀⢸⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠑⠀⢄⠀⡰⠁⠀⠀⠀⠀⠀⠈⠉⠁⠈⠉⠻⠋⠉⠛⢛⠉⠉⢹⠁⢀⢇⠎⠀⠀⢸⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⠈⠢⢄⡉⠂⠄⡀⠀⠈⠒⠢⠄⠀⢀⣀⣀⣰⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⢀⣎⠀⠼⠊⠀⠀⠀⠘⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⡀⠉⠢⢄⡈⠑⠢⢄⡀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⢀⠀⠀⠀⠀⠀⢻⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⣀⡈⠑⠢⢄⡀⠈⠑⠒⠤⠄⣀⣀⠀⠉⠉⠉⠉⠀⠀⠀⣀⡀⠤⠂⠁⠀⢀⠆⠀⠀⢸⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⣄⡀⠁⠉⠒⠂⠤⠤⣀⣀⣉⡉⠉⠉⠉⠉⢀⣀⣀⡠⠤⠒⠈⠀⠀⠀⠀⣸⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣶⣤⣤⣤⣤⣀⣀⣤⣤⣤⣶⣾⣿⣿⣿⣿⣿
        "
    fi
fi

afficher_histoire "Merci d'avoir joué à l'aventure du jeune pirate informatique !"
