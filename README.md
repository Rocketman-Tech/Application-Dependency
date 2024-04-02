# Application Dependency
Waits for Core Applications to Install. Typically used for Dock Items with App Installers or Mac App Store Apps. 

## The Problem
Imagine this scenario: You set up a provisioning workflow within Jamf Pro, and you rely on Jamf App Installers to be installed before setting up the user's dock. But the issue is you can't control WHEN the dock is setup, so instead, you need to create a policy that checks to see if certain applications exist on the user's computer before continuing

## Policy Parameters
[policytrigger]='' ## Policy to run after condition above has been met. EG: openChromeWebpages
[timeout]='300' ## Timeout in seconds. EG: 1800
[waitforuser]='' ## 'true' if you want to wait for the user to login before running. EG: true
[domain]='tech.rocketman.appdependency' ## Plist that the preferences will be stored. 

## Managed Plist Parameters
You can set any of the policy parameters above using a managed plist. Here's an example of what this looks like:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>policytrigger</key>
		<string>dock</string>
		<key>timeout</key>
		<string>300</string>
		<key>waitforuser</key>
		<string>true</string>
	</dict>
</plist>

```

## Defining Dependent Applications
Applications you want to wait to be installed before running can only be defined through either a local or managed plist. Here's an example: 

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>Application</key>
		<array>
			<string>/Applications/iMazing Profile Editor.app/</string>
			<string>/Applications/Harvest.app/</string>
			<string>/Applications/CodeRunner.app/</string>
			<string>/Applications/ClickUp.app/</string>
			<string>/Applications/Slack.app/</string>
		</array>
	</dict>
</plist>
```
