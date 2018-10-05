#!/usr/bin/env bash

# Prometheus Alertmanager URL
URL="http://prd-prometheus-server:9093"
# URL to Prometheus Alertmanager API
API="$URL/api/v1/alerts"
# Your favorite web browser
BROWSER=/usr/bin/google-chrome-stable

# Image for the gnome shell extension icon (SVG)
IMG='
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"
	 width="20px" height="20px" viewBox="0 0 115.333 114" enable-background="new 0 0 114 114" xml:space="preserve">
<g id="Layer_2">
</g>
<g>
	<path fill="§COLOR§" d="M56.667,0.667C25.372,0.667,0,26.036,0,57.332c0,31.295,25.372,56.666,56.667,56.666
		s56.666-25.371,56.666-56.666C113.333,26.036,87.961,0.667,56.667,0.667z M56.667,106.722c-8.904,0-16.123-5.948-16.123-13.283
		H72.79C72.79,100.773,65.571,106.722,56.667,106.722z M83.297,89.04H30.034v-9.658h53.264V89.04z M83.106,74.411h-52.92
		c-0.176-0.203-0.356-0.403-0.526-0.609c-5.452-6.62-6.736-10.076-7.983-13.598c-0.021-0.116,6.611,1.355,11.314,2.413
		c0,0,2.42,0.56,5.958,1.205c-3.397-3.982-5.414-9.044-5.414-14.218c0-11.359,8.712-21.285,5.569-29.308
		c3.059,0.249,6.331,6.456,6.552,16.161c3.252-4.494,4.613-12.701,4.613-17.733c0-5.21,3.433-11.262,6.867-11.469
		c-3.061,5.045,0.793,9.37,4.219,20.099c1.285,4.03,1.121,10.812,2.113,15.113C63.797,33.534,65.333,20.5,71,16
		c-2.5,5.667,0.37,12.758,2.333,16.167c3.167,5.5,5.087,9.667,5.087,17.548c0,5.284-1.951,10.259-5.242,14.148
		c3.742-0.702,6.326-1.335,6.326-1.335l12.152-2.371C91.657,60.156,89.891,67.418,83.106,74.411z"/>
</g>
</svg>
'

# Get http return code of alert manager call
RET=$(curl -s -o /dev/null -w "%{http_code}" $API)


# If http return code is 200 (OK) continue ...
if [ "$RET" == "200" ]; then
  # Get alerts and hostnames from alert manager api (json). Use § as separator between alertname and hostname.
  # Only monitor alerts with active state but not suppressed/silenced.
  DATA=$(curl -s $API)
  ALERTS=$(echo $DATA | jq '.data[] | "\(.labels.alertname)§\(.labels.hostname)§\(.status.state)§\(.labels)§"' | grep '§active§' | sed 's/^"//g' | sed 's/"$//g' | sort -u)
  HOSTS=$(echo $DATA | jq '.data[] | "\(.labels.hostname)§\(.labels.alertname)§\(.status.state)§"' | grep '§active§' | sed 's/^"//g' | sed 's/"$//g' | sort -u)
  # Count the number of alerts
  ALERTCOUNT=$(echo "$ALERTS" | wc -l)

  # If the number of alerts is not 0 the display them ...
  if [ $ALERTCOUNT -ne 0 ] && [ "$ALERTS" != "" ]; then
    # Use icon color for alerts
    ICON="image='$(echo $IMG | sed 's/§COLOR§/#e5512b/g' | base64 -w 0)'"
    # Print the number of alerts
    echo "$ALERTCOUNT alerts | $ICON"
    echo "---"

    # Link to the Alertmanager
    echo -e "\e[1mGO TO ALERTMANAGER | bash='$BROWSER $URL' terminal=false"

    # Create the list of hosts
    if [ $(echo "$HOSTS" | grep -v null | wc -l) -gt 0 ]; then
      echo -e "\e[1mBY HOST"
    fi
    HOSTNAME=""
    ALERTNAME=""
    while IFS= read -r HOST; do
      # Save last hostname for next iteration
      LASTHOSTNAME=$HOSTNAME
      # Get alert name and host
      HOSTNAME=$(echo $HOST | awk -F '§' '{print $1}')
      ALERTNAME=$(echo $HOST | awk -F '§' '{print $2}')

      if [ "$HOSTNAME" != "null" ]; then
        # Print the hostname if it changed since the last iteration 
        if [ "$HOSTNAME" != "$LASTHOSTNAME" ]; then
          echo "--  :computer: $HOSTNAME | bash='/usr/bin/gnome-terminal -- ssh root@$HOSTNAME' terminal=false"
        fi

        # Print the alert
        echo "--     $ALERTNAME | size=8"
      fi
    done <<< "$HOSTS"

    # Now create the list of alerts
    echo -e "\e[1mBY ALERT"
    HOSTNAME=""
    ALERTNAME=""
    while IFS= read -r ALERT; do
      # Save last alert name for next iteration
      LASTALERTNAME=$ALERTNAME
      # Get alert name and host
      ALERTNAME=$(echo $ALERT | awk -F '§' '{print $1}')
      HOSTNAME=$(echo $ALERT | awk -F '§' '{print $2}')
      LABELS=$(echo $ALERT | awk -F '§' '{print $4}')
 
      # Print the alert name if it changed since the last iteration 
      if [ "$ALERTNAME" != "$LASTALERTNAME" ]; then
        echo "$ALERTNAME"
      fi

      if [ "$HOSTNAME" != "null" ]; then
        # Print the host and set the command to create an ssh connection when clicking on it
        echo "--  :computer: $HOSTNAME | bash='/usr/bin/gnome-terminal -- ssh root@$HOSTNAME' terminal=false size=8"
      else
        echo "--  $LABELS | size=8" | sed 's/\\",\\"/, /g' | sed 's/"//g' | sed 's/{//g' | sed 's/}//g'
      fi
    done <<< "$ALERTS"
  # ... else print no alerts and use different icon color
  else
    ICON="image='$(echo $IMG | sed 's/§COLOR§/#5eb220/g' | base64 -w 0)'"
    echo "| $ICON"
    echo "---"
    echo "no alerts"
  fi
# ... else display conneciton error and use different icon color
else
  ICON="image='$(echo $IMG | sed 's/§COLOR§/#0186d1/g' | base64 -w 0)'"
  echo "| $ICON"
  echo "---"
  echo "connection error"
fi
