import os
import random
import time

folder_user = './../LACHAINE'

def genesis():
    print("Lancement de la chaine")
    with open("chaine.txt", "w") as fichier:
        fichier.write("")

def get_users_account():
    if os.path.isdir(folder_user):
        users_name = os.listdir(folder_user)
        return users_name

def regeneration_account(users_name):
    for user in users_name:
        with open(os.path.join(folder_user, user), "w") as fichier:
            fichier.write("N=100")

def create_block(users_name):
        with open("block.txt", "w") as fichier:
            fichier.write("")
        for i in range(10):
            transaction = create_transaction(users_name)
        
def create_transaction(users_name):
    debtor = random.choice(users_name)
    creditor = random.choice(users_name)
    while debtor == creditor:
        creditor = random.choice(users_name)
    payment = random.randint(1, 50)
    print('debtor:', debtor, 'creditor:', creditor, 'payment:', payment)
    debit_value(debtor, payment)
    credit_value(creditor, payment)
    with open("block.txt", "a") as fichier:
            timestamp = int(time.time())
            fichier.write(str(timestamp)+' '+debtor+"= -"+str(payment)+'\n')
            fichier.write(str(timestamp)+' '+creditor+"= +"+str(payment)+'\n')

def debit_value(debtor, payment):
    with open(os.path.join(folder_user, debtor), "r") as fichier:
        account = fichier.read()
        account_value = int(account.split("=")[1])
    new_account_value = "N="+ str(account_value - payment)
    with open(os.path.join(folder_user, debtor), "w") as fichier:
        fichier.write(new_account_value)


def credit_value(creditor, payment):
    with open(os.path.join(folder_user, creditor), "r") as fichier:
        account = fichier.read()
        account_value = int(account.split("=")[1])
    new_account_value = "N="+ str(account_value + payment)
    with open(os.path.join(folder_user, creditor), "w") as fichier:
        fichier.write(new_account_value)


def get_account_value(user):
    path = os.path.join(folder_user, user)
    with open(path, "r") as fichier:
        contenu_lu = fichier.read()
        print(user, contenu_lu)

def push_to_chaine():
        with open("block.txt", "r") as fichier:
            block = fichier.read()
        with open("chaine.txt", "a") as fichier:
            fichier.write(block)

genesis()
users_name = get_users_account()
regeneration_account(users_name)
for i in range(10):
    time.sleep(1)
    create_block(users_name)
    push_to_chaine()


