#!/bin/sh

#--- Constantes globales ----
s_NOM="EZ-Build"
s_VERSION="0.2RC" 
i_HAUTEURFEN=10
i_LARGEURFEN=50

s_TMPROOT="/tmp/EZBuild"
s_TMPDIALOG="$s_TMPROOT/tmpdialog"
s_TMPDIRDDL="$s_TMPROOT/telechargement"
s_TMPDIREXTRACT="$s_TMPROOT/extraction"


s_MSG_BIENVENUE="Bonjour. Bienvenue dans EZ-Setup !"
s_MSGERR_PAQUET="Erreur:Un paquet nécessaire au bon fonctionnement du programme n'est pas installé.Vérifiez que le paquet suivant est installé:"
s_MSG_QUELLEADRESSE="Veuillez indiquer l'adresse internet du fichier compressé contenant les sources"
s_MSG_TELECHARGE="Téléchargement du fichier en cours. Le temps de l'opération dépend de la rapidité de votre connexion internet. Veuillez patienter..."
s_MSG_EXTRACT="Extraction en cours. Le temps de l'opération dépend des ressources CPU disponibles. Veuillez patienter..."
s_MSG_QUELLECONFIG="Veuillez entrer la ligne de configuration:(dans le doute laissez la chaine par défaut)"
s_MSG_QUELMAKE="Veuillez entrer la commande make: (dans le doute laissez la commande par défaut)"
s_MSG_retelecharger="Le fichier semble déjà avoir été téléchargé. Voulez-vous utiliser le fichier déjà existant?(Sans réponse de votre part d'ici 15 secondes, le fichier sera téléchargé à nouveau)"
s_MSGERR_ARCHIVEINVALIDE="Le fichier téléchargé est corrompu ou n'est pas actuellement pris en charge par EZ-Build"
s_MSGERR_NODIALOG="Erreur: le paquet dialog n'est pas installé"
s_MSG_FINREUSSITE="La compilation s'est terminée avec succès. Vous pouvez trouver les fichiers générés dans le dossier $s_TMPDIREXTRACT"

dialog --help > /dev/null
if ! [ $? -eq 0 ]; then
	echo $s_MSGERR_NODIALOG
	exit 20
fi


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
        cd "$s_TMPDIRDDL"
        wget "$URL" 2>&1 | \
         stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
         dialog --title "$s_NOM $s_VERSION" --gauge "$s_MSG_TELECHARGE" $i_HAUTEURFEN $i_LARGEURFEN
}




verif pv
verif wget
verif make
verif awk

mkdir $s_TMPROOT
mkdir $s_TMPDIRDDL
mkdir $s_TMPDIREXTRACT


dialog --title "$s_NOM $s_VERSION" --msgbox "$s_MSG_BIENVENUE" $i_HAUTEURFEN $i_LARGEURFEN
dialog --title "$s_NOM $s_VERSION" --nocancel --inputbox "$s_MSG_QUELLEADRESSE" $i_HAUTEURFEN $i_LARGEURFEN "http://site.com/sources.zip"  2>  "$s_TMPDIALOG"
adresse=$(cat "$s_TMPDIALOG")

#Téléchargement du fichier
fichiercompresse="$s_TMPDIRDDL/$(basename $adresse)"
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
rm -Rf $s_TMPDIREXTRACT
mkdir $s_TMPDIREXTRACT

#Vérifie la validité d'une archive
#entrée:$1: chemin complet de l'archive à vérifier
#sortie: 1 si valide, 0 si invalide
archivevalide(){
	tar -tzf $1 >/dev/null 2> /dev/null
	if ! [ $? -eq 0 ];then
		dialog --title "$s_NOM $s_VERSION" --msgbox "$s_MSGERR_ARCHIVEINVALIDE($(basename $1))" $i_HAUTEURFEN $i_LARGEURFEN
		exit 21
		return 1
	fi
	return 0
}
archivevalide $fichiercompresse
(pv -n $fichiercompresse | tar xzf - -C $s_TMPDIREXTRACT ) 2>&1 | dialog --title "$s_NOM $s_VERSION" --gauge "$s_MSG_EXTRACT" $i_HAUTEURFEN $i_LARGEURFEN
#Le fichier est décompressé

#Récupère le chemin complet du dossier où ont été extraites les données.
#entrée:néant
#sortie:chemin complet du dossier
getDossierResExtraction(){
	cd $s_TMPDIREXTRACT
	echo "$s_TMPDIREXTRACT/$(ls | tail -n 1)"
}
dossierTravail=$(getDossierResExtraction)

dialog --title "$s_NOM $s_VERSION" --nocancel --inputbox "$s_MSG_QUELLECONFIG" $i_HAUTEURFEN $i_LARGEURFEN "configure"  2>  $s_TMPDIALOG
ligneconf=$(cat $s_TMPDIALOG)
cd $dossierTravail
$dossierTravail/$ligneconf > "$s_TMPDIREXTRACT/config.log" 2>&1

if ! [ $? -eq 0 ];then
	echo "EZ-BUILD:une erreur s'est produite...." > "$s_TMPDIREXTRACT/config.logdialog"
	echo "--------------------------------------" >> "$s_TMPDIREXTRACT/config.logdialog"
	tail -n 5 "$s_TMPDIREXTRACT/config.log" >> "$s_TMPDIREXTRACT/config.logdialog"
	dialog --textbox "$s_TMPDIREXTRACT/config.logdialog" 15 70
	exit 1
fi

dialog --title "$s_NOM $s_VERSION" --nocancel --inputbox "$s_MSG_QUELMAKE" $i_HAUTEURFEN $i_LARGEURFEN "make"  2>  $s_TMPDIALOG
lignemake=$(cat $s_TMPDIALOG)
$dossierTravail/$lignemake  > "$s_TMPDIREXTRACT/make.log" 2>&1
if ! [ $? -eq 0 ];then
        echo "EZ-BUILD:une erreur s'est produite...." > "$s_TMPDIREXTRACT/make.logdialog"
        echo "--------------------------------------" >> "$s_TMPDIREXTRACT/make.logdialog"
        tail -n 5 "$s_TMPDIREXTRACT/make.log" >> "$s_TMPDIREXTRACT/make.logdialog"
        dialog --textbox "$s_TMPDIREXTRACT/make.logdialog" 15 70
        exit 1
fi

dialog --title "$s_NOM $s_VERSION" --msgbox "$s_MSG_FINREUSSITE" $i_HAUTEURFEN $i_LARGEURFEN
