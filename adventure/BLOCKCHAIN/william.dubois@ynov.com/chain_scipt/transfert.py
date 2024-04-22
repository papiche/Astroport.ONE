import random
import string
import os
from datetime import datetime
import sys


def transfer(source, dest, amount):
    if source == dest:
        print("Source and destination accounts cannot be the same.")
        return
    
    if "user_accounts" not in source:
        source = "user_accounts/" + source
    if "user_accounts" not in dest:
        dest = "user_accounts/" + dest

    try:
        with open(source, 'r') as source_file:
            source_balance = float(source_file.read().strip())
        
        with open(dest, 'r') as dest_file:
            dest_balance = float(dest_file.read().strip())
        
        if source_balance < amount:
            print("Insufficient funds in the source account.")
            return
        
        source_balance -= amount
        dest_balance += amount
        
        with open( source, 'w') as source_file:
            source_file.write(str(source_balance))
        
        with open( dest, 'w') as dest_file:
            dest_file.write(str(dest_balance))
        
        print(f"Transfer of {amount} completed successfully.")
        with open('transfer_log.txt', 'a') as log_file:
            log_file.write(f"{datetime.now()}: {source} -> {amount} -> {dest} \n")
    
    except FileNotFoundError:
        print("One or both of the users does not exist.")
    except ValueError:
        print("File content is not a valid number.")
    except Exception as e:
        print(f"An error occurred: {e}")



def create_random_users(num_users):
    try:
        os.makedirs("user_accounts", exist_ok=True)
        
        for i in range(num_users):
            
            username = ''.join(random.choices(string.ascii_uppercase, k=8))
            
            user_file = f"{username}.txt"
            
            balance = 100
            
            with open('user_accounts/'+ user_file, 'w') as file:
                file.write(str(balance))
            
            print(f"User {i+1}: Username - {username}, Source File - {user_file}, Balance - {balance}")
    
    except Exception as e:
        print(f"An error occurred: {e}")



def get_random_user_accounts():
    user_files = os.listdir("user_accounts")
    
    if len(user_files) < 2:
        print("Insufficient user accounts to perform transactions.")
        return None, None
    
    user1_file = random.choice([file for file in user_files])
    user2_file = random.choice([file for file in user_files if file != user1_file])
    
    return user1_file, user2_file



def perform_random_transaction():
    # Get two random user accounts
    user1_file, user2_file = get_random_user_accounts()
    
    if user1_file is None or user2_file is None:
        return
    
    try:
        # Extract usernames from file names
        user1 = user1_file
        user2 = user2_file
        print(f"Performing transaction from {user1} to {user2}")
        
        # Generate a random amount for the transaction
        amount = random.randint(10, 100)
        
        # Perform the transaction
        transfer(user1, user2, amount)
    
    except Exception as e:
        print(f"An error occurred: {e}")



# create_random_users(7)
# perform_random_transaction()
        


if __name__ == '__main__':
    args = sys.argv

    if len(args) == 4:
        transfer(args[1], args[2], float(args[3]))
    else:
        perform_random_transaction()

