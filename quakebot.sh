#!/bin/bash 

homedir=$1
keyfile=$homedir/keyfile
feltfile=$homedir/feltfile
lastquake=$homedir/lastquake
tempfile=$homedir/tempfile

cd $homedir

# Grab the json of the latest quake
curl -s -H "Accept: application/vnd.geo+json;version=2" https://api.geonet.org.nz/quake?MMI=3 | jq '.features[0]' > $tempfile

#{
#  "type": "Feature",
#  "geometry": {
#    "type": "Point",
#    "coordinates": [
#      172.4193726,
#      -43.55522919
#    ]
#  },
#  "properties": {
#    "publicID": "2017p433631",
#    "time": "2017-06-10T10:38:49.269Z",
#    "depth": 8.714474678,
#    "magnitude": 4.160633307,
#    "locality": "15 km west of Christchurch",
#    "mmi": 5,
#    "quality": "best"
#  }
#}


oldid=`cat $lastquake`
newid=`cat $tempfile | jq '.properties.publicID' | sed "s/\"//g" `

if [ "$newid" = "$oldid" ]
then
   echo "ID is the same: $newid "
   exit 0
fi

mag=`cat $tempfile | jq '.properties.magnitude' | xargs printf '%.*f\n' 1 `
qtime=`cat $tempfile | jq '.properties.time' | xargs -I{} date -d {} +%a,\ %b\ %d\ %Y,\ %r `
qloc=`cat $tempfile | jq '.properties.locality' | sed "s/\"//g" `
qdepth=`cat $tempfile | jq '.properties.depth' | xargs printf '%.*f\n' 0 `
east=`cat $tempfile | jq '.geometry.coordinates[0]' `
south=`cat $tempfile | jq '.geometry.coordinates[1]' `

echo "QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km"

# TODO - if the quake was more than say 30 minutes ago. Add the ID to the lastquake

# Check description appears okay to cut down on FPs

# Sample " Mag 2.6, Thursday, December 3 2009 at 7:23 am (NZDT), 10 km north-west of Ohakune. "
# Sample: QUAKE: Mag 3.5, Wed, October 17 2012 at 1:27:27 pm, 15 km east of Te Araroa. Depth: 27 km
# echo "$desc"| grep "^Mag.*:.*NZ.*of.*"

echo "QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km " | grep "^QUAKE.*Mag.*:.*km.*of.*"
if [ $? -gt 0 ]
then
    echo "Description bad"
    echo "$desc"
    echo `date +%F\ %X ` "NOT TWEETED Description bad - QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km" >> $homedir/tweets.log
    exit 0
fi

# 

echo "Full URL is https://www.geonet.org.nz/earthquake/$newid" 
fullurl="https://www.geonet.org.nz/earthquake/$newid"
# tinyurl=`curl -s http://tinyurl.com/api-create.php?url=$fullurl `
# echo "Tiny URL is $tinyurl "
# echo "TEST $desc $tinyurl "

# Send the Tweet

# Do not tweet if magnatude less than 4
# Shouldn't happen anyway due to API but
MAGTEST=`echo "$mag < 4" | bc`
if [ $MAGTEST -eq 1 ]
then
   echo "Magnitute of $a is less than 4, not going to tweet"
   echo `date +%F\ %X ` "NOT TWEETED MAG less than 4 - QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km #eqnz $fullurl" >> $homedir/tweets.log
   exit 0
fi

# Looks like we are going to tweet this so save ID
echo $newid > $lastquake

echo `date +%F\ %X ` "QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km #eqnz $fullurl" >> $homedir/tweets.log

# Look for minus dot space dot
echo "$south $east "| grep "^\-.*\..*\ .*\."
if [ $? -gt 0 ]
then
    echo "Geo not found"
    $homedir/oysttyer.pl -verbose -keyf=$keyfile -status="QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km #eqnz $fullurl"

else
    echo "geo found"
    $homedir/oysttyer.pl -verbose -keyf=$keyfile -lat=$south -long=$east -status="QUAKE: Mag $mag, $qtime, $qloc. Depth: $qdepth km #eqnz $fullurl" 
fi

rm $tempfile
