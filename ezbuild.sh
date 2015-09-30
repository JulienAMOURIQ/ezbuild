#!/bin/sh
dialog --help > /dev/null
if ! [ $? -eq 0 ]; then
	echo "Erreur: le paquet dialog n'est pas installé"
	exit 20
fi

#--- Constantes globales ----
s_NOM="EZ-Build"
s_VERSION="0.1" 
i_HAUTEURFEN=10
i_LARGEURFEN=50

s_MSG_BIENVENUE="Bonjour. Bienvenue dans EZ-Setup !"
s_MSGERR_PAQUET="Erreur:Un paquet nécessaire au bon fonctionnement du programme n'est pas installé.Vérifiez que le paquet suivant est installé:"
s_MSG_QUELLEADRESSE="Veuillez indiquer l'adresse internet du fichier compressé contenant les sources"
s_MSG_TELECHARGE="Téléchargement du fichier en cours. Le temps de l'opération dépend de la rapidité de votre connexion internet. Veuillez patienter..."
s_MSG_EXTRACT="Extraction en cours. Le temps de l'opération dépend des ressources CPU disponibles. Veuillez patienter..."
s_MSG_QUELLECONFIG="Veuillez entrer manuellement la ligne de configuration:"
s_MSG_retelecharger="Le fichier semble déjà avoir été téléchargé. Voulez-vous utiliser le fichier déjà existant?(Sans réponse de votre part d'ici 15 secondes, le fichier sera téléchargé à nouveau)"
#vérifie qu'un programme est installé.Dans le cas contraire stop le script après avoir affiché un message
#entree: $1 nom du programme
#sortie: néant
verif(){
	$1 --help > /dev/null
	if ! [ $? -eq 0 ]; then
		dialog --title "$s_NOM $s_VERSION" --msgbox "$s_MSGERR_PAQUET ($1)" $i_HAUTEURFEN $i_LARGEURFEN
		clear
		exit 20
	fi
}

#télécharge le fichier à l'adresse passée en paramètre en affichant la progression
#entrée: $1: URL du fichier à télécharger
#sortie: néant
gwget(){
        local URL=$1
        cd /tmp/
        wget "$URL" 2>&1 | \
         stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
         dialog --title "$s_NOM $s_VERSION" --gauge "$s_MSG_TELECHARGE" $i_HAUTEURFEN $i_LARGEURFEN
}




verif pv
verif wget
verif make
verif awk

dialog --title "$s_NOM $s_VERSION" --msgbox "$s_MSG_BIENVENUE" $i_HAUTEURFEN $i_LARGEURFEN
dialog --title "$s_NOM $s_VERSION" --nocancel --inputbox "$s_MSG_QUELLEADRESSE" $i_HAUTEURFEN $i_LARGEURFEN "http://"  2>  /tmp/tmpez
adresse=$(cat /tmp/tmpez)

#Téléchargement du fichier
fichiercompresse="/tmp/$(basename $adresse)"
if [ -e $fichiercompresse ] ;then
	dialog --title "$s_NOM $s_VERSION" --timeout 15 --defaultno --yesno  "$s_MSG_retelecharger" $i_HAUTEURFEN $i_LARGEURFEN 
	if ! [ $? -eq 0 ] ;then #0=on veut utiliser le fichier existant
		rm $fichiercompresse
	fi
fi

if ! [ -e $fichiercompresse ];then
	gwget $adresse
fi

#Le fichier est téléchargé


#Décompression du fichier
mkdir /tmp/EZSetup
rm -Rf /tmp/EZSetup
mkdir /tmp/EZSetup

(pv -n $fichiercompresse | tar xzf - -C /tmp/EZSetup ) 2>&1 | dialog --title "$s_NOM $s_VERSION" --gauge "$s_MSG_EXTRACT" $i_HAUTEURFEN $i_LARGEURFEN
#Le fichier est décompressé

#Récupère le chemin complet du dossier où ont été extraites les données.
#entrée:néant
#sortie:chemin complet du dossier
getDossier(){
	cd /tmp/EZSetup
	echo "/tmp/EZSetup/$(ls | tail -n 1)"
}
dossierTravail=$(getDossier)

dialog --title "$s_NOM $s_VERSION" --nocancel --inputbox "$s_MSG_QUELLECONFIG" $i_HAUTEURFEN $i_LARGEURFEN "configure"  2>  /tmp/tmpez
ligneconf=$(cat /tmp/tmpez)
$dossierTravail/$ligneconf

