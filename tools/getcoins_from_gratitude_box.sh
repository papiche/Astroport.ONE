#!/bin/bash
##########################
## GRATITUDE BOX SIMULATOR
##########################
## distribute $1 units on $2 coins.
##  get a random coin, read units
##  GRATITUDE ~= 3 ( min = 1  max = 21 )
##########################
# Set coins & units parameters
total_units=$1
[[ $total_units == ""  ]] && total_units=30
total_coins=$2
[[ $total_coins == ""  ]] && total_coins=10


[[ $total_units -lt $total_coins ]] \
    && echo 0 \
    && exit 1

put_units_on_coins() {
      local coins=()

      # Initialize an array to store the units for each coin
      declare -a coin_units

      # Initialize each coin with at least 1 unit
      for ((i = 0; i < total_coins; i++)); do
        coin_units[$i]=1
        ((total_units--))
      done

      # Distribute the remaining units randomly
      for ((i = 0; i < total_units; i++)); do
        coin=$((RANDOM % total_coins))
        ((coin_units[$coin]++))
      done

      # Print the distribution
      for ((i = 0; i < total_coins; i++)); do
        coins+=( ${coin_units[$i]} )
        #echo "Coin $((i + 1)): ${coin_units[$i]} units"
      done

      echo "${coins[@]}"
}

# Function to randomly pick one coin
pick_random_coin() {
  local coins=("$@")
  local random_index=$((RANDOM % ${#coins[@]}))
  local picked_coin=${coins[$random_index]}
  echo "$picked_coin"
}

# Simulate putting units on coins
coin_values=($(put_units_on_coins))
# debug
# echo "${coin_values[@]}"
# Randomly pick one coin
pick_random_coin "${coin_values[@]}"
exit 0
