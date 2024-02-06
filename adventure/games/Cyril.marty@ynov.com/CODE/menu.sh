#!/bin/bash
clear
#récupérer la varible nom
nom="$1"
position=Entrée 
    # Afficher dynamiquement les informations du personnage à chaque fois que le menu s'affiche
cat "personnages/$nom/$nom.txt"
echo "-----------------------"
cat "personnages/$nom/$nom-fichier_stats.txt"
echo "-----------------------"

# Menu principal
while true; do
clear
    echo "--------------------------------------------------------------------------------"
    echo "                                Menu Principal                                  "
    echo "--------------------------------------------------------------------------------"
    echo ""
    echo " vous êtes actuellement : $position"
    echo ""
    echo ""
    echo ""
    echo "                                    ___       "
    echo "                                   |___|____  "
    echo "                                  /     \\    "
    echo "                                 | () () |    "
    echo "                                  \\  ^  /    "
    echo "                                   |||||      "
    echo "                                  /|||||\      "
    echo "                                  \|||||/     "
    echo "                                   |||||      "
    echo "                                   |||||     "
    echo "                                  /_\ /_\     "
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo "1. Ouvrir le Sac                                               4. Regarder"
    echo "2. Ouvrir la carte                                             5. Agir"
    echo "3. Ouvir son portmonnaie                                       6. Se déplacer"
    echo "                                                        "
    echo "                                  7. Quitter le jeu"
    echo "                                         FDP"
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "                                                                                "
    echo "--------------------------------------------------------------------------------"

    read -p "Choisissez une option (1/2/3/4/5/6/7) : " choix

case $choix in
    1)
        # Insérez ici le code pour ouvrir le sac
        echo "Le sac n'est pas encore implémenté."
        ;;
    2)
        # Insérez ici le code pour ouvrir la carte
        if [ -f "map.sh" ]; then
            ./map.sh  # Exécuter le script si présent
        else
            echo "La carte n'est pas encore implémentée."
        fi  # Fin du bloc if
        ;;  # Fin de l'option 4
    3)
        cat "personnages/$nom/$nom-inventaire.txt"
        ;;
    4)
        afficher_statistiques_personnage
        ;;

    5)
        cat "personnages/$nom/$nom-inventaire.txt"
        ;;
    6)
        echo "-------------------------------------"
        echo "                                     "
        echo "-------------------------------------"
        echo "vous êtes actuellement ici : $position"
        echo "regarder la map pour plus d'information"
        echo "-------------------------------------"
        echo "Voici la liste des directions possible"  
        echo "1.Accueil"
        echo "2.Escalier"
        echo "3.Récréation"
        echo "4.CDI"
        echo "5.Cantine"
        echo "6.Salle cours 1"
        echo "7.Salle cours 2"
        echo "8.Salle cours 3"
        echo "9.Salle cours 4"
        echo "10.Salle cours 5"
        echo "11.Salle cours 7"
        echo "12.Salle cours 8"
        echo "13.Concièrge"
        echo "14.Terrain de Basket"
        echo "15.Le coin fumeur"
        read -p "ou souhaites tu aller ? 1/2/3/4/5/6/7/8/..." lieu
        case $lieu in 
    		1)
			echo "comme tout personnes normal vous allez à l'acceuil"
        		./accueil.sh
          		;;
	        2)
        		echo "intriger par les escalier vous décider d'y aller"
        		if [ -f "personnages/$nom:inventaire.txt/baseball" ]; then
			echo "le pion se dirige vers vous mais vous lui donner un coup de batte de basebell"
			echo "il semble plus donner signe de vie mais l'escalier vous intrige plus que ça vie insignifiante"
           		 ./escalier.sh  # Exécuter le script si présent
        		else
            		echo "Un pion surgit de nulle part et vous attrape pour vous ammener à l'acceui"
			./accueil.sh
        		fi  # Fin du bloc if
        		;;  # Fin de l'option 2
    		3)
        		echo "Le chemin pour allez à l'ecole  vous a fatiguer il est temps d'aller en pause"
			./recreation
        		;;
    		4)
        		echo "Pourquoi ne pas aller au CDI"
			./CDI.sh
        		;;

    		5)
        		cat "personnages/$nom/$nom-inventaire.txt"
        		;;
    		6)

        		;;
    		7)
        		exit
        		;;

    		8)
        		# Insérez ici le code pour ouvrir le sac
        		echo "Le sac n'est pas encore implémenté."
        		;;
    		9)
        		# Insérez ici le code pour ouvrir la carte
        		if [ -f "map.sh" ]; then
            		./map.sh  # Exécuter le script si présent
        		else
            		echo "La carte n'est pas encore implémentée."
        		fi  # Fin du bloc if
        		;;  # Fin de l'option 4
    		10)
        		cat "personnages/$nom/$nom-inventaire.txt"
       			;;
    		11)
        		afficher_statistiques_personnage
        		;;

    		12)
        		cat "personnages/$nom/$nom-inventaire.txt"
        		;;
    		13)
			;;
   		 *)
        		echo "Option invalide. Veuillez choisir une option valide."
        		;;
		esac
		read -p "Appuyez sur une touche pour continuer..."
                ;;

	7)
        ;;
	*)
        echo "Option invalide. Veuillez choisir une option valide."                        ;;

esac
done
