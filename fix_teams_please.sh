#!/bin/bash
##############################################################################
##############################################################################
##############################################################################
##############################################################################
#
# fix_teams_please.sh
# v1.0b3
# 05.23.2024
#
# Greg Knackstedt
# shitttyscripts@gmail.com
# https://github.com/scriptsandthings
#
# Original version was "Borrowed" from 2.0b.pkg at https://office-reset.com/
# using Suspicious Package.
#
# Very un-tested, 100% broken/incomplete.
#
##############################################################################
##############################################################################
##############################################################################
##############################################################################
#
# To fix the Teams things/stuff [Will add script info here later]
#
##############################################################################
############################## Define Variables Block ########################
##############################################################################
#
echo "Fix my Teams, Please: Starting postinstall script"
autoload is-at-least
APP_NAME="Microsoft Teams"
#
#
##### Set Shared Download Folder Path
SharedDownloadFolder="/Users/Shared/OnDemandInstaller/"
#
#
##### Check and set currently installed version of macOS
CurrentmacOSVersion=$(sw_vers -productVersion)
#
#
##############################################################################
############################## Define Function Block #########################
##############################################################################
#
#
##### Get username of currently logged in local/console user and define the user's home directory
GetCurrentConsoleUser() {
	# Use scutil to identify the currently logged in user and set as $CurrentConsoleUser
	CurrentConsoleUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
	##### Set Currently Logged In User Home Directory
	HOME=/Users/"${CurrentConsoleUser}"
	# Echo current logged in user to sdout
	echo "Current Local User: ${CurrentConsoleUser}"
	# Echo current logged in user's home folder to sdout
	echo "User Home Folder: ${HOME}"
}
#
#
#
InstallLatestTeams() {
    # Assign a value to SharedDownloadFolder if it's not already set
    SharedDownloadFolder="/Users/Shared/OnDemandInstaller/"
    
    if [ -d "${SharedDownloadFolder}" ]; then
        rm -rf "${SharedDownloadFolder}"
    fi
    mkdir -p "${SharedDownloadFolder}"

    # Fetch the latest version number from the Microsoft documentation page
    VERSIONNUMBER=$(curl -s https://learn.microsoft.com/en-us/officeupdates/teams-app-versioning | 
        awk '/<h4 id="mac-version-history">Mac version history<\/h4>/,/<\/table>/' | 
        grep -A 3 '(Rolling out)' | 
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | 
        head -n 1)

    # Construct the download URL
    TeamsDownloadURL="https://statics.teams.cdn.office.net/production-osx/${VERSIONNUMBER}/MicrosoftTeams.pkg"

    CDN_PKG_URL=$(/usr/bin/nscurl --location --head "${TeamsDownloadURL}" --dump-header - | awk '/Location/' | cut -d ' ' -f2 | tail -1 | awk '{$1=$1};1')
    echo "Fix my Teams, Please: Package to download is ${CDN_PKG_URL}"
    CDN_PKG_NAME=$(/usr/bin/basename "${CDN_PKG_URL}")

    CDN_PKG_SIZE=$(/usr/bin/nscurl --location --head "${TeamsDownloadURL}" --dump-header - | awk '/Content-Length/' | cut -d ' ' -f2 | tail -1 | awk '{$1=$1};1')
    CDN_PKG_MB=$((CDN_PKG_SIZE / 1000 / 1000))
    echo "Fix my Teams, Please: Download package is ${CDN_PKG_MB} megabytes in size"

    echo "Fix my Teams, Please: Starting ${APP_NAME} package download"
    /usr/bin/nscurl --background --download --large-download --location --download-directory "${SharedDownloadFolder}" "${TeamsDownloadURL}"
    echo "Fix my Teams, Please: Finished package download"

    LOCAL_PKG_SIZE=$(cd "${SharedDownloadFolder}" && stat -f%z "${CDN_PKG_NAME}")
    if [[ "${LOCAL_PKG_SIZE}" == "${CDN_PKG_SIZE}" ]]; then
        echo "Fix my Teams, Please: Downloaded package is wholesome"
    else
        echo "Fix my Teams, Please: Downloaded package is malformed. Local file size: ${LOCAL_PKG_SIZE}"
        echo "Fix my Teams, Please: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
        exit 0
    fi

    LOCAL_PKG_SIGNING=$(/usr/sbin/pkgutil --check-signature "${SharedDownloadFolder}/${CDN_PKG_NAME}" | awk '/Developer ID Installer'/ | cut -d ':' -f 2 | awk '{$1=$1};1')
    if [[ "${LOCAL_PKG_SIGNING}" == "Microsoft Corporation (UBF8T346G9)" ]]; then
        echo "Fix my Teams, Please: Downloaded package is signed by Microsoft"
    else
        echo "Fix my Teams, Please: Downloaded package is not signed by Microsoft"
        echo "Fix my Teams, Please: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
        exit 0
    fi

    echo "Fix my Teams, Please: Starting package install"
    if sudo /usr/sbin/installer -pkg "${SharedDownloadFolder}/${CDN_PKG_NAME}" -target /; then
        echo "Fix my Teams, Please: Package installed successfully"
    else
        echo "Fix my Teams, Please: Package installation failed"
        echo "Fix my Teams, Please: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
        exit 0
    fi
}
#
#
#
FindEntryTeamsIdentity() {
	/usr/bin/security find-generic-password -l 'Microsoft Teams Identities Cache' 2> /dev/null 1> /dev/null
	echo $?
}
#
#
##### Check if any MS Teams apps/process are running and force quit/kill them if found
FindAndKillTeamsProcesses() {
	PROCESSES=$(/bin/ps ax | /usr/bin/grep "[/]Applications/Microsoft Teams" | /usr/bin/awk '{ print $1 }')
	for PROCESS_ID in ${PROCESSES}; do
		kill -9 "$PROCESS_ID"
	done
}
#
#
# Find "Microsoft Teams.app"
CheckForMicrosoftTeamsAppBundle() {
	if [ -d "/Applications/Microsoft Teams.app" ]; then
		APP_VERSION=$(defaults read /Applications/Microsoft\ Teams.app/Contents/Info.plist CFBundleVersion)
		APP_BUNDLEID=$(defaults read /Applications/Microsoft\ Teams.app/Contents/Info.plist CFBundleIdentifier)
		echo "Found version ${APP_VERSION} of Microsoft Teams.app with bundle ID ${APP_BUNDLEID}"
		if [[ "${APP_BUNDLEID}" == "com.microsoft.teams" ]]; then
			if ! is-at-least 611156.0 "${APP_VERSION}" && is-at-least 10.15 "${CurrentmacOSVersion}"; then
				echo "Fix my Teams, Please: The installed version of ${APP_NAME} is ancient. Updating it now"
				InstallLatestTeams
			fi
		fi
	fi
}
#
#
##### Find "Microsoft Teams classic.app"
CheckForMicrosoftTeamsClassicAppBundle() {
	if [ -d "/Applications/Microsoft Teams classic.app" ]; then
			echo "The Microsoft Teams classic.app bundle is installed and will be removed and replaced with the latest version of Microsoft Teams.app."
			FindAndKillTeamsProcesses 
			/bin/rm -rf /Applications/Microsoft\ Teams\ classic.app
			InstallLatestTeams
	fi
}
#
#
# Find "Microsoft Teams (work or school).app"
CheckForMicrosoftTeamsWorkOrSchoolAppBundle() {
	if [ -d "/Applications/Microsoft Teams (work or school).app" ]; then
			echo "/Applications/Microsoft Teams (work or school).app bundle is installed and will be removed and replaced with the latest version of Microsoft Teams.app."
			FindAndKillTeamsProcesses
			/bin/rm -rf /Applications/Microsoft\ Teams\ \(work\ or\ school\).app
			InstallLatestTeams
	fi
}
#
#
##### Remove all Microsoft Teams* .app bundles from /Applications
RemoveAllTeamsAppBundles() {
	/bin/rm -rf "/Applications/Microsoft Teams"*.app
}
#
#
##### Remove Microsoft Teams classic.app bundle from /Applications
RemoveTeamsClassicAppBundle() {
	/bin/rm -rf "/Applications/Microsoft Teams classic.app"
}
#
#
##### Remove Microsoft Teams (work or school).app bundle from /Applications
RemoveTeamsWorkandSchoolAppBundle() {
	/bin/rm -rf "/Applications/Microsoft Teams (work or school).app"
}
#
#
# Remove Microsoft Teams.app bundle from /Applications
RemoveTeamsAppBundle() {
	/bin/rm -rf "/Applications/Microsoft Teams.app"
}
#
#
# Remove caches for "The New Teams""/Teams (work or school)/Teams 2 from current user's home directory
ClearTeams2Cache() {
	rm -rf /Users/"$CurrentConsoleUser"/"Library/Group Containers/UBF8T346G9.com.microsoft.teams"
	rm -rf /Users/"$CurrentConsoleUser"/"Library/Containers/com.microsoft.teams2"
}
#
#
##############################################################################
############################## Script Run Block ##############################
##############################################################################
#
#
echo "Fix my Teams, Please - Running as: ${CurrentConsoleUser}; Home Folder: ${HOME}"
#
#
##### Check if any MS Teams apps/process are running and force quit/kill them if found
FindAndKillTeamsProcesses
#
#
echo "Removing configuration data for Microsoft Teams (all versions)"
/bin/rm -rf "${HOME}"/Library/Application\ Support/Teams
/bin/rm -rf "${HOME}"/Library/Application\ Support/Microsoft/Teams
/bin/rm -rf "${HOME}"/Library/Application\ Support/com.microsoft.teams
/bin/rm -rf "${HOME}"/Library/Application\ Support/com.microsoft.teams.helper

/bin/rm -rf "${HOME}"/Library/Application\ Scripts/UBF8T346G9.com.microsoft.teams
/bin/rm -rf "${HOME}"/Library/Application\ Scripts/com.microsoft.teams2
/bin/rm -rf "${HOME}"/Library/Application\ Scripts/com.microsoft.teams2.launcher
/bin/rm -rf "${HOME}"/Library/Application\ Scripts/com.microsoft.teams2.notificationcenter

/bin/rm -rf "${HOME}"/Library/Caches/com.microsoft.teams
/bin/rm -rf "${HOME}"/Library/Caches/com.microsoft.teams.helper
/bin/rm -f "${HOME}"/Library/Cookies/com.microsoft.teams.binarycookies
/bin/rm -f "${HOME}"/Library/HTTPStorages/com.microsoft.teams.binarycookies
/bin/rm -rf "${HOME}"/Library/HTTPStorages/com.microsoft.teams
/bin/rm -rf "${HOME}"/Library/Logs/Microsoft\ Teams
/bin/rm -rf "${HOME}"/Library/Logs/Microsoft\ Teams\ Helper
/bin/rm -rf "${HOME}"/Library/Logs/Microsoft\ Teams\ Helper \(Renderer\)
/bin/rm -rf "${HOME}"/Library/Saved\ Application\ State/com.microsoft.teams.savedState
/bin/rm -rf "${HOME}"/Library/WebKit/com.microsoft.teams

/bin/rm -rf "${HOME}"/Library/Containers/com.microsoft.teams2
/bin/rm -rf "${HOME}"/Library/Containers/com.microsoft.teams2.launcher
/bin/rm -rf "${HOME}"/Library/Containers/com.microsoft.teams2.notificationcenter
/bin/rm -rf "${HOME}"/Library/Group\ Containers/UBF8T346G9.com.microsoft.teams
/bin/rm -rf "${HOME}"/Library/Group\ Containers/UBF8T346G9.com.microsoft.oneauth

/bin/rm -rf /Library/Application\ Support/TeamsUpdaterDaemon
/bin/rm -rf /Library/Application\ Support/Microsoft/TeamsUpdaterDaemon
/bin/rm -rf /Library/Application\ Support/Teams

/bin/rm -f "${HOME}"/Library/Preferences/com.microsoft.teams.plist
/bin/rm -f /Library/Managed\ Preferences/com.microsoft.teams.plist
/bin/rm -f /Library/Preferences/com.microsoft.teams.plist
/bin/rm -f "${HOME}"/Library/Preferences/com.microsoft.teams.helper.plist
/bin/rm -f /Library/Managed\ Preferences/com.microsoft.teams.helper.plist
/bin/rm -f /Library/Preferences/com.microsoft.teams.helper.plist

/bin/rm -rf "${TMPDIR}"/com.microsoft.teams
/bin/rm -rf "${TMPDIR}"/com.microsoft.teams\ Crashes
/bin/rm -rf "${TMPDIR}"/Teams
/bin/rm -rf "${TMPDIR}"/Microsoft\ Teams\ Helper\ \(Renderer\)
/bin/rm -rf "${TMPDIR}"/v8-compile-cache-501

/bin/rm -rf /Library/Logs/Microsoft/Teams

KeychainHasLogin=$(/usr/bin/sudo -u $"${CurrentConsoleUser}" /usr/bin/security list-keychains | grep 'login.keychain')
if [ "$KeychainHasLogin" = "" ]; then
	echo "Fix my Teams, Please: Adding user login keychain to list"
	/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security list-keychains -s "${HOME}"/"Library/Keychains/login.keychain-db"
fi

echo "Display list-keychains for logged-in user"
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security list-keychains


while [[ $(FindEntryTeamsIdentity) -eq 0 ]]; do
	/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'Microsoft Teams Identities Cache'
done
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'Teams Safe Storage'
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'Microsoft Teams (work or school) Safe Storage'
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'teamsIv'
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'teamsKey'
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.teams.HockeySDK'
/usr/bin/sudo -u "${CurrentConsoleUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.teams.helper.HockeySDK'

exit 0
