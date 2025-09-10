#!/bin/bash
# Update and install Apache2
apt update
apt install -y apache2

# Install Google Cloud SDK
apt install -y apt-transport-https ca-certificates gnupg curl
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
  | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt update && apt install -y google-cloud-sdk

# Start and enable Apache2
systemctl start apache2
systemctl enable apache2

# GCP Metadata server base URL and header
METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
METADATA_FLAVOR_HEADER="Metadata-Flavor: Google"

# Use curl to fetch instance metadata
local_ipv4=$(curl -H "${METADATA_FLAVOR_HEADER}" -s "${METADATA_URL}/instance/network-interfaces/0/ip")
zone=$(curl -H "${METADATA_FLAVOR_HEADER}" -s "${METADATA_URL}/instance/zone")
project_id=$(curl -H "${METADATA_FLAVOR_HEADER}" -s "${METADATA_URL}/project/project-id")
network_tags=$(curl -H "${METADATA_FLAVOR_HEADER}" -s "${METADATA_URL}/instance/tags")

#Logic for zone sensitivity
full_zone=$(echo "$zone" | awk -F/ '{print $NF}')
region=$(echo "$full_zone" | sed 's/-[a-z]$//')

case "$full_zone" in
  *-a)
    bg_image="https://i.imgur.com/MhKxc8e.jpeg"
    video_url="https://imgur.com/gallery/wait-W0aydBM#e8HDPrL"
    ;;
  *-b)
    bg_image="https://i.imgur.com/gaaY0T2.jpeg"
    video_url="https://imgur.com/gallery/sup-w8SOGAp#phl2cDS"
    ;;
  *-c)
    bg_image="https://i.imgur.com/vm3iG93.jpeg"
    video_url="https://imgur.com/gallery/doggo-houser-Bve2Ix2#/t/dogos"
    ;;
  *)
    bg_image="https://i.imgur.com/ADZbhBu.jpeg"
    video_url="https://imgur.com/gallery/do-fetch-tho-kczlFlX#/t/dogos"
    ;;
esac


# Create the HTML page
sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Class 6.5</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://www.w3schools.com/w3css/4/w3.css">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Montserrat">
  <style>
    body,h1,h3 {font-family: "Montserrat", sans-serif}
    body, html {height: 100%}
    .bgimg {
      background-image: url('$bg_image');
      min-height: 100%;
      background-position: center;
      background-size: cover;
    }
    .w3-display-middle {
      background-color: rgba(0, 0, 0, 0.466);
      padding: 20px;
      border-radius: 10px;
    }
    .transparent-background {
      background-color: rgba(0, 0, 0, 0.575);
      padding: 20px;
      border-radius: 10px;
    }
    .rounded-image {
      border-radius: 25px;
    }
  </style>
</head>
<body>
  <div class="bgimg w3-display-container w3-animate-opacity w3-text-white">
    <div class="w3-display-topleft w3-padding-large w3-xlarge"></div>
    <div class="w3-display-middle w3-center">
      <video width="360" height="540" style="border-radius:10px;" controls loop autoplay muted>
          <source src="$video_url" type="video/mp4">
          Your browser does not support the video tag.
      </video>
      <hr class="w3-border-grey" style="margin:auto;width:40%;margin-top:15px;">
      <h3 class="w3-large w3-center" style="margin-top:15px;">
        <a href="https://github.com/Gwenbleidd32/startup-script-template"
           class="w3-button w3-transparent w3-border w3-border-white w3-round-large w3-text-white"
           style="margin-bottom:0px;"
           target="_blank">
          Source Code
        </a>
      </h3>
    </div>
    <div class="w3-display-bottomright w3-padding-small transparent-background outlined-text">
      <h1>My Compute Instance Information</h1>
      <h3></h3>
      <p><b>Instance Name:</b> $(hostname -f)</p>
      <p><b>Instance Private IP Address: </b> $local_ipv4</p>
      <p><b>Zone: </b> $full_zone</p>
      <p><b>Project ID:</b> $project_id</p>
      <p><b>Network Tags:</b> $network_tags</p>
    </div>
  </div>
</body>
</html>
EOF