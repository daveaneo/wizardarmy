#!/usr/bin/python3

from brownie import Wizards, Token, WizardTower, WizardBattle, accounts, network, config
import json
import os
from datetime import date

DUMP_ABI = True
dev = accounts.add(config["wallets"]["from_key"]) # accounts[0]
secondary = accounts.add(config["wallets"]["secondary"]) # accounts[1]
print(f'network: {network.show_active()}')
for i in range(2):
    print(f'accounts[{i}]: {accounts[i]}')


def main():
    token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})
    wizards = Wizards.deploy("Wizards", "WZD", token.address, {'from': accounts[0]})
    wizard_tower = WizardTower.deploy(token.address, wizards.address, {'from': accounts[0]})
    wizard_battle = WizardBattle.deploy(token.address, wizards.address, wizard_tower.address, {'from': accounts[0]})

    # save addresses
    directory = os.getcwd()
    # path = os.path.join(directory, "abi_dump")
    # print(f'path: {path}')
    abi = str(wizards.abi)
    file_path = os.path.join(directory, "deployed_contracts.txt")
    with open(file_path, 'a') as file:
        file.write("\n\n******************************************")
        file.write(f"\n*********   {date.today()}    **************")
        file.write("\n******************************************")
        file.write(f'\ntoken: {token}')
        file.write(f'\nwizardsNFT: {wizards}')
        file.write(f'\nwizard_tower: {wizard_tower}')
        file.write(f'\nwizard_battle: {wizard_battle}')

    # set modifier addresses
    tx = wizards.updateBattler(wizard_battle.address, {'from': accounts[0]})
    tx = wizard_tower.updateBattler(wizard_battle.address, {'from': accounts[0]})

    # create wizards
    for i in range(5):
        tx = wizards.mint({'from': accounts[1]})
        tx.wait(1)
        tx = wizard_tower.claimFloor(i, {'from': accounts[1]})
        tx.wait(1)

    ts = wizards.totalSupply()
    print(f'total wizards: {ts}')

    if DUMP_ABI:
        print(f'dumping wizardTower...') # sdf sfd sdfsdf sdf
        directory = os.getcwd()
        path = os.path.join(directory, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizard_tower.abi)
        file_path = os.path.join(path, "wizardtower.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)

        print(f'dumping wizards...') # sdf sfd sdfsdf sdf
        directory = os.getcwd()
        path = os.path.join(directory, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizards.abi)
        file_path = os.path.join(path, "wizards.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)

        print(f'dumping wizardBattle...') # sdf sfd sdfsdf sdf
        directory = os.getcwd()
        path = os.path.join(directory, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizard_battle.abi)
        file_path = os.path.join(path, "wizardbattle.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)


        # todo -- save addresses

    # return Wizards.deploy("Wizards", "WZD", {'from': accounts[0]})
