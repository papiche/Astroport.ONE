import sys
from datetime import datetime
import random
        
def enregistrer_transaction(source,destination,montant):
    heure = datetime.now().strftime("%d-%m-%Y %H:%M:%S")
    
    with open('journal_transaction.txt', 'a') as journal:
        journal.write(f"{heure} : {source} a envoyé {montant} à {destination}\n")

def transfert_montant(source,destination,montant):
    
    if source == destination:
        print("Transaction annulée, l'utilisateur ne peut pas s'envoyer des fonds à lui même")
        return
    
    with open(source,'r') as f_source:
        montant_source = int(f_source.read())
    
    if montant_source < montant:
        print(f"Solde de {source} insuffisant")
        return
        
    with open(destination,'r') as f_destination:
        montant_destination= int(f_destination.read())
        
    montant_source -= montant
    montant_destination += montant
    
    with open(source,'w') as f_source:
        f_source.write(str(montant_source))
        
    with open(destination,'w') as f_destination:
        f_destination.write(str(montant_destination))
        
    enregistrer_transaction(source,destination,montant)
    
def generer_random(n):
    for _ in range(n):
        source = f"N{random.randint(1,7)}"
        destination = f"N{random.randint(1,7)}"
        
        while destination == source:
            destination = f"N{random.randint(1,7)}"
            
        montant = random.randint(1,10)
        
        try:
            transfert_montant(source,destination,montant)
        except Exception as e:
            print(f"Erreur lors de la transaction : {e}")
    
    
if __name__ == "__main__":
    if len(sys.argv) == 4 :
        source = sys.argv[1]
        destination = sys.argv[2]
        montant = int(sys.argv[3])
        transfert_montant(source,destination,montant)
    else:
        if len(sys.argv) > 1 :
            if sys.argv[1] == "random":
                n_transactions = 20
                generer_random(n_transactions)
            else:
                print("Cas d'usage : python3 transfert.py random")
        
