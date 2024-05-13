#!/bin/bash

# Vérification de la présence de kubectl
if ! command -v kubectl &> /dev/null; then
    echo "kubectl n'est pas installé. Veuillez installer kubectl et configurer votre cluster Kubernetes."
    exit 1
fi

# Demander le chemin du fichier YAML modèle
read -p "Chemin du fichier YAML modèle : " yaml_file

# Convertir le chemin relatif en chemin absolu
yaml_file=$(readlink -f "$yaml_file")

echo "Chemin absolu du fichier YAML modèle : $yaml_file"

# Vérifier si le fichier existe
if [ ! -f "$yaml_file" ]; then
    echo "Le fichier YAML spécifié n'existe pas."
    exit 1
fi

# Demander le nom du nouveau fichier YAML
read -p "Nom du nouveau fichier YAML (avec le chemin complet) : " output_file

# Définir les variables nécessaires
read -p "Nom du déploiement : " deployment_name
read -p "Nombre de réplicas : " replicas
read -p "Nom de l'image Docker : " image_name
read -p "Port exposé (containerPort) : " container_port

# Copier le fichier YAML modèle vers le nouveau fichier de sortie
cp "$yaml_file" "$output_file"

# Remplacer les valeurs dans le nouveau fichier YAML
sed -i "s/{{DEPLOYMENT_NAME}}/$deployment_name/g" "$output_file"
sed -i "s/{{REPLICAS}}/$replicas/g" "$output_file"
sed -i "s/{{IMAGE_NAME}}/$image_name/g" "$output_file"
sed -i "s/{{CONTAINER_PORT}}/$container_port/g" "$output_file"

# Afficher le contenu du nouveau fichier YAML
echo "Contenu du nouveau fichier YAML :"
cat "$output_file"

# Déployer le fichier YAML dans le cluster Kubernetes
echo "Déploiment du template générer"
kubectl apply -f "$output_file"

echo "Déploiement effectué avec succès."
