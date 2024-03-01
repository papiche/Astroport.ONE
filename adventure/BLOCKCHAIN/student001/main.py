N_TOTAL = 1000

from time import sleep  
import random




def read_sold(user):
    sold = 0
    with open(f'./LACHAINE/{user}.txt', 'r') as file:
        file_content = file.read()
        sold = float(file_content)
    return sold



def write_sold(user, sold):
    with open(f'./LACHAINE/{user}.txt', 'w') as file:
        file.write(str(sold))






def read_tx():
    transactions = []
    with open('./tx_list.txt', 'r') as file:
        file_content = file.read()
        transactions = file_content.split('\n')

    tx = []
    for t in transactions:
        tx.append(t.split(','))
    return tx


def main():
    tx = read_tx()
    for t in tx:
        sleep(0.1)
        demandeur = t[5]
        montant = float(t[4])
        montant_without_commission = montant - 0.10
        N1 = t[1]
        if N1 != demandeur:
            print(f'tx:{t[0]: <4} -> Processing transaction 🚫')
            continue
        print(f'tx:{t[0]: <4} -> Processing transaction ✅')
        N2 = t[2]
        tx_type = t[3]
        sold_N1 = read_sold(N1)
        sold_N2 = read_sold(N2)
        if tx_type == '-':
            sold_N1 -= montant_without_commission
            sold_N2 += montant_without_commission
        elif tx_type == '+':
            sold_N1 -= montant_without_commission
            sold_N2 -= montant_without_commission
        write_sold(N1, sold_N1)
        write_sold(N2, sold_N2)
        N0_sold = read_sold('N0')
        write_sold('N0',N0_sold+0.1)


def tx_generator():
    file_path = './tx_list.txt'
    try:
        with open(file_path, 'w') as file:
            for i in range(1, 1000):
                n_i = random.randint(1, 10)
                n_i_plus_1 = random.randint(1, 10)
                n_demandeur = random.randint(1, 10)
                montant = random.randint(1, 10)
                tx_type = random.choice(['-', '+'])
                if i == 999:
                    line = f"{i},N{n_i},N{n_i_plus_1 if i < 10 else 1},{tx_type},{montant},N{n_demandeur}"
                else:
                    line = f"{i},N{n_i},N{n_i_plus_1 if i < 10 else 1},{tx_type},{montant},N{n_demandeur}\n"
                file.write(line)

        print(f"Content successfully written to '{file_path}'.")

    except Exception as e:
        print(f"An error occurred: {e}")


def reset_account():
    for i in range(0, 11):
        with open(f'./LACHAINE/N{i}.txt', 'w') as file:
            if i == 0:
                file.write('0')
            else:
                file.write('100')
    print('Reset done')



if __name__ == '__main__':
    tx_generator()
    reset_account()
    main()