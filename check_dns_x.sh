#!/bin/bash

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

PROOFIP=$(nslookup $HOST $XCHECKDNSSERVER | awk '/^Address: / { print "-a", $2 }')

$CHECKKCOMMAND -H $HOST -s $DNSSERVER $PROOFIP