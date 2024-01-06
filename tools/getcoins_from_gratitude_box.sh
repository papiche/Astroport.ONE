#!/bin/bash
##########################
## GRATITUDE BOX SIMULATOR
##########################
## distribute 30 units on 10 coins.
##  get a random coin, read units
##  GRATITUDE ~= 3 ( min = 1  max = 21 )
##########################

put_units_on_coins() {
      local coins=()
      total_units=30
      total_coins=10

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

# Simulate putting 30 units on 10 coins
coin_values=($(put_units_on_coins))
# echo "${coin_values[@]}"
# Randomly pick one coin
pick_random_coin "${coin_values[@]}"
