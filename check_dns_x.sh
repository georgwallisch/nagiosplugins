#!/bin/bash

XCHECKDNSSERVER="9.9.9.9"
TIMEOUT="60"

while [[ $# -gt 0 ]]; do
  case $1 in
    -C)
      CHECKKCOMMAND="$2"
      shift # past argument
      shift # past value
      ;;
    -H)
      HOST="$2"
      shift # past argument
      shift # past value
      ;;
    -s)
      DNSSERVER="$2"
      shift # past argument
      shift # past value
      ;;
     -x)
      XCHECKDNSSERVER="$2"
      shift # past argument
      shift # past value
      ;;    
     -t)
      TIMEOUT="$2"
      shift # past argument
      shift # past value
      ;;    
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

#PROOFIP=$(nslookup $HOST $XCHECKDNSSERVER | awk '/^Address: / { print "-a", $2 }')
PROOFIP=$($CHECKKCOMMAND -H $HOST -t $TIMEOUT -s $XCHECKDNSSERVER | grep -o -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

$CHECKKCOMMAND -H $HOST -t $TIMEOUT -s $DNSSERVER $PROOFIP