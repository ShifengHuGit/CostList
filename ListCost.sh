#! /bin/bash
# Version 0.1 
# 2019-10-17 frist release
#
# Shifeng.hu@oracle.com 
#  Oracle(China) Dalian 
#  SEHUB OCI team


while read line;do  
    eval "$line"  
done < account.conf  



  iam_url="identity.us-ashburn-1.oraclecloud.com"
  meter_endpoint="https://itra.oraclecloud.com/"
  cost_url="metering/api/v1/usagecost"
  TEMP_Req="/tmp/Req.json"

function printHelp {

 echo "Usage: ./ListCost -t \"<StartTime>  <EndTime>\"   [ -a | -c <CompartmentNameList> ] [-v] [-h]"
 echo " [-t]: to specify the duration for checking the cost."
 echo "   It is mandatory to specify the duration for use"
 echo "   StartTime/EndTime format must be: YYYY-MM-DDThh:mm:ss.000"
 echo "   e.g.  -t \"2019-09-10T00:00:00.000 2019-09-14T00:00:00.000\""
 echo " [-a]: To check all Compartments under the RootCompartmentID cost"
 echo " [-c \"<CompartmentNameList>\"]: To check specified Compartments under the RootCompartmentID cost, multi compartments shoud be splited by space"
 echo "   e.g. -c \"CompartmentDevelop Managment Sales\""
 echo " [-a] or [-c <CompartmentNameList>] must be specified to check the cost"
 echo " [-v] if specified, the detail output will be given "
exit

}



function ListCost {


    local alg=rsa-sha256
    local sigVersion="1"
    local now="$(LC_ALL=C \date -u "+%a, %d %h %Y %H:%M:%S GMT")"
    local host=$1
    local method=$2
    local extra_args
    local keyId="$tenancyId/$authUserId/$keyFingerprint"
    
#
    local iam_url="identity.us-ashburn-1.oraclecloud.com"



    case $method in

        "get" | "GET")
            local target=$3
            extra_args=("${@: 4}")
            local curl_method="GET";
            local request_method="get";
            ;;

        *) echo "invalid method"; return;;
    esac

    # This line will url encode all special characters in the request target except "/", "?", "=", and "&", since those characters are used 
    # in the request target to indicate path and query string structure. If you need to encode any of "/", "?", "=", or "&", such as when
    # used as part of a path value or query string key or value, you will need to do that yourself in the request target you pass in.
    local escaped_target="$(echo $( rawurlencode "$target" ))"
    
    local request_target="(request-target): $request_method $escaped_target"
    local date_header="date: $now"
    local host_header="host: $host"
    local content_sha256_header="x-content-sha256: $content_sha256"
    local content_type_header="content-type: $content_type"
    local content_length_header="content-length: $content_length"
    local signing_string="$request_target\n$date_header\n$host_header"
    local headers="(request-target) date host"
    local curl_header_args
    curl_header_args=(-H "$date_header")
    local body_arg
    body_arg=()

    if [ "$curl_method" = "PUT" -o "$curl_method" = "POST" ]; then
        signing_string="$signing_string\n$content_sha256_header\n$content_type_header\n$content_length_header"
        headers=$headers" x-content-sha256 content-type content-length"
        curl_header_args=("${curl_header_args[@]}" -H "$content_sha256_header" -H "$content_type_header" -H "$content_length_header")
        body_arg=(--data-binary @${body})
    fi

    local sig=$(printf '%b' "$signing_string" | \
                openssl dgst -sha256 -sign $privateKeyPath | \
                openssl enc -e -base64 | tr -d '\n')

    curl "${extra_args[@]}" "${body_arg[@]}" -X $curl_method -sS https://${host}${escaped_target} "${curl_header_args[@]}" \
        -H "Authorization: Signature version=\"$sigVersion\",keyId=\"$keyId\",algorithm=\"$alg\",headers=\"${headers}\",signature=\"$sig\""
}

# url encode all special characters except "/", "?", "=", and "&"
function rawurlencode {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] | "/" | "?" | "=" | "&" ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done

  echo "${encoded}"
}

function DebugPara {

 
   DebugComp=(`ListCost  $iam_url  get "/20160918/compartments?compartmentId=$RootCompartmentID&compartmentIdInSubtree=true&limit=1000"|\
    jq  '.[] | select(.lifecycleState == "ACTIVE")'|jq -r .name`)
   DebugServiceName=`curl -s -X GET -u "$idcs_user:$idcs_psw" -H "X-ID-TENANT-NAME:$idcs_GUID" \
    https://itra.oraclecloud.com/itas/$idcs_GUID/myservices/api/v1/serviceEntitlements |\
    jq -r '.items[].serviceDefinition.name'`



}

###### Main part ###########################

AllFlag=0 
quietMode=1
Prog=0
Tflag=0
SpCompart=0
detailMode=0
b='#'


touch /tmp/tmp.file
#tput rmam
Cols=$(tput cols)

ARGS=`getopt -o ac:qvpt:h -- "$@"`

eval set -- "$ARGS"


while [ $# -gt 0 ]
do

  case $1 in
      -a) 
         AllFlag=1; shift;;   
        
      -c)  
        #echo "Here is!"
          SpCompart=1
          CompartArray="$2"
          #echo $CompartArray
          shift 2
          ;;
     # -q) quietMode=1; shift;;

      -h) printHelp; shift;;

      -v) detailMode=1; shift;; 

     # -p) Prog=1 ; shift;;

      -t) Tflag=1

          StartTime=$(echo $2|awk '{print $1}')
          EndTime=$(echo $2|awk '{print $2}')  
          shift 2
          ;;
     --)  shift; break ;;
      *) echo "Invalid Option exit";
            exit
          break ;;

  esac
done



#echo $Tflag

if [ $Tflag -ne 1 ]; then
    echo "***** You must specify a duration for checking the cost， format like below： *****"
    echo "*****      -t YYYY-MM-DDThh:mm:ss.000 YYYY-MM-DDThh:mm:ss.000                *****"
    echo "*****    e.g.  -t \"2019-09-10T00:00:00.000 2019-09-14T00:00:00.000\"            *****"

exit
fi



if [ $AllFlag -eq 0 -a  $SpCompart -eq 0 ]; then
    echo "***** You must specify a compartment list by [-c] option or use [-a] to show all cost under your root compartmentID  ****"
    exit
fi


if [ $SpCompart -eq 1 ]; then
    SubCompartmentId=($CompartArray)
else
    #touch CompartmentFile.log
    #ListCost  $iam_url  get "/20160918/compartments?compartmentId=$RootCompartmentID&compartmentIdInSubtree=true&limit=1000" > CompartmentFile.log
    SubCompartmentId=(`ListCost  $iam_url  get "/20160918/compartments?compartmentId=$RootCompartmentID&compartmentIdInSubtree=true&limit=1000"|\
    jq  '.[] | select(.lifecycleState == "ACTIVE")'|jq -r .name`)

fi



###
# 1st try to access the IDCS via Curl to see if there is some error happened 
###
# if 401 is returned , means there is misconfigure for IDCS account
#
IDCS_HTTPCODE=`curl -sIL -X GET -u "$idcs_user:$idcs_psw" \
	-w  %{http_code} -H "X-ID-TENANT-NAME:$idcs_GUID"  \
	-o /dev/null \
	https://itra.oraclecloud.com/itas/$idcs_GUID/myservices/api/v1/serviceEntitlements`
if [ $IDCS_HTTPCODE -ne 200 ];then
	echo -e "\033[33mError! HTTP Return code: \033[31m$IDCS_HTTPCODE \033[0m"
		if [ $IDCS_HTTPCODE -eq 401 ];then
			echo -e "\033[33mAuthErr. Account name: \033[31m$idcs_user \033[0m"
			echo -e "\033[33mPlease check your account name or passowrd in accout.conf\033[0m"
		fi
	exit

fi

ServiceName=`curl -s -X GET -u "$idcs_user:$idcs_psw" -H "X-ID-TENANT-NAME:$idcs_GUID" \
https://itra.oraclecloud.com/itas/$idcs_GUID/myservices/api/v1/serviceEntitlements |\
jq -r '.items[].serviceDefinition.name'`



NumberofCompartment=${#SubCompartmentId[@]}

echo "---------------------------------------------------------------------------------------------- "
echo "-----------Calulating the Cost for Compartment:$NumberofCompartment ， Please wait for a while ------------------ "
echo -e "---------------------------------------------------------------------------------------------- \n"



for ((i=0;$i<=NumberofCompartment;i+=1)) 
    do
{
    if [ $Prog -eq 1 ]; then
        printf "progress:[%-50s]%s%%\r" $b $(echo "scale=2; $i/$NumberofCompartment*100"|bc -l)
    fi


    touch $TEMP_Req
    echo "" > $TEMP_Req

    for Serv in $ServiceName;
        do
            {
                 Req=`curl -s -X GET -u "$idcs_user:$idcs_psw" -H "X-ID-TENANT-NAME:$idcs_GUID" \
"$meter_endpoint/$cost_url/$idcs_accountID/tagged?\
startTime=$StartTime&\
endTime=$EndTime&\
usageType=TOTAL&\
serviceName=$Serv&\
tags=ORCL:OCICompartmentName=${SubCompartmentId[$i]}&\
computeTypeEnabled=Y&\
dcAggEnabled=Y&\
rollupLevel=RESOURCE"`;
                echo $Req >> $TEMP_Req

} &

        done
        wait


        Req=`cat $TEMP_Req | jq 'reduce inputs as $i (.; .items += $i.items)'`

	if [ ! -n $Len ];then
		echo " ----- Nothing responsed via REST api for getting the enrolled services and cost usage,        ---- "
		echo " ----- There might be incorrect account information within account.conf or network unreachable ---- " 
		exit
	else
        	Len=`echo $Req | jq -r '.items | length'`
	fi
	
    if [ $Len -eq 0 ];then
        #echo "No cost at $name"
        continue

    else
       #echo $Req | jq '[.items[]|select(.costs[].computedAmount != 0)]'  | jq '.[].dataCenterId'

        DatacenterList=`echo $Req | jq '[.items[]|select(.costs[].computedAmount != 0)]' |jq -r '.[].dataCenterId' | sort |uniq`
        #echo $DatacenterList
        sum=`echo $Req | jq 'def roundit: .*100.0|round/100.0; [.items[].costs[].computedAmount]| add |roundit'`
        currency=`echo $Req | jq  -r '.items[].currency'|uniq`
        TempLength=`echo  "|  Compartment : ${SubCompartmentId[$i]}      |     TotalCost : $sum $currency  |"`
        TempLength=${#TempLength} 


if [ $detailMode -eq 1 ];then

        printf "%-${TempLength}s\n" "-"|sed -e 's/ /-/g' 
        echo -e "|  \033[33mCompartment : \033[31m${SubCompartmentId[$i]}  \033[0m    |     \033[33mTotalCost : \033[31m$sum $currency  \033[0m|"
        printf "%-${TempLength}s\n" "-"|sed -e 's/ /-/g' 

      
      #List the cost by Datacenter, to use this function, must put the flag: dcAggEnabled=Y into the CURL Metering API.
      #   
      for DC in $DatacenterList;
        do
          echo -e "  <<<<<<<<<- Region : \033[33m$DC\033[0m ->>>>>>>>>"

        echo $Req | jq  --arg DataCenterName $DC '[.items[]|select((.costs[].computedAmount != 0) and (.dataCenterId == $DataCenterName))]'|\
        jq -r  --arg DisplayCurrency " $currency" \
        'def roundit: .*100.0|round/100.0; [
            [ 
                .[].resourceDisplayName|
                gsub(" ";"")|gsub("OracleAutonomousDataWarehouse";"ADW")|
                gsub("-TeraByteStorageCapacityPerMonth";"")
            ],
            [  (.[].costs[].computedAmount|roundit|tostring)+$DisplayCurrency]
        ]|
        transpose|
        map( {(.[0]): .[1]})|
        add'
        #echo "-------------------------" 
      done



else

        printf "%-${Cols}s\n" "-"|sed -e 's/ /-/g' 
        echo $Req | jq  '[.items[]|select(.costs[].computedAmount != 0)]'|\
        jq -r --arg DisplayName ${SubCompartmentId[$i]}  --arg DisplayTotal $sum \
            '["[Compartment]", "[TotalCost]" ], 
             [ $DisplayName, $DisplayTotal ]
             |@tsv'|\
             awk '{ 
                for(i=1;i<=NF;i++)
                    { 
                        ORS = " | "; 
                        if(i == NF) {ORS = "\n"};
                        if($i ~ /^[0-9\.]+$/) 
                            { $i=sprintf ("%.2f", $i); print $i  DisplayCurrency} 
                        else 
                            { print $i }
                    }
                 }'  DisplayCurrency=$currency \
            | column -t

fi


        if [ $Prog -eq 1 ]; then
        printf "%-${Cols}s\n" "-"|sed -e 's/ /-/g' >> ./tmp.file
        else
        printf "%-${TempLength}s\n\n" "-"|sed -e 's/ /-/g'
        fi
        #echo "Total : $sum \t"
    fi


} 


  b=#$b
done
#wait




