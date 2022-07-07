#!/usr/bin/python3

from brownie import Wizards, Token, WizardTower, WizardBattle, accounts, network, config
from brownie.network.state import Chain
import json
import os
from datetime import date
import time

DUMP_ABI = True
dev = accounts.add(config["wallets"]["from_key"]) # accounts[0]
secondary = accounts.add(config["wallets"]["secondary"]) # accounts[1]
print(f'network: {network.show_active()}')
chain = network.state.Chain()
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
    tx.wait(1)

    # create wizards
    for i in range(2):
        tx = wizards.mint({'from': accounts[1]})
        tx.wait(1)
        tx = wizards.initiate(i, {'from': accounts[1]})
        tx.wait(1)
        tx = wizard_tower.claimFloor(i, {'from': accounts[1]})
        tx.wait(1)

    ts = wizards.totalSupply()
    print(f'total wizards: {ts}')

    # fuel tower
    tx = token.transfer(wizard_tower.address, 10**6, {'from': accounts[0]} )
    tx.wait(1)

    # current_block = chain.time()
    # todo -- this is giving issues. When sleep is high, second balance goes to zero
    # todo - at 60*9, it says we don't own wizard (from contract?)
    floor_two_stats = wizard_tower.floorIdToInfo(2)
    print(f'floor_two_stats: {floor_two_stats}')
    current_block = chain.time()
    print(f'current block: {current_block}')

    chain.sleep(60*9)
    chain.mine(1)
    print(f'sleeping...')
    floor_two_stats = wizard_tower.floorIdToInfo(2)
    print(f'floor_two_stats: {floor_two_stats}')
    current_block = chain.time()
    print(f'current block: {current_block}')

    # attack
    tower_balance = token.balanceOf(wizard_tower.address);

    print(f'Balances before...')
    print(f'tower balance : {tower_balance}')
    # for x in range(0,2):
    #     floor = wizard_tower.wizardIdToFloor(x, {'from': accounts[1]} )
    #     print(f'wizard {x} is on floor: {floor}')


    time.sleep(3)
    for x in range(1, 3):
        floor_balance = wizard_tower.floorBalance(x, {'from': accounts[1]} )
        print(f'floor_balance {x}: {floor_balance}')

    for x in range(1, 3):
        floor_power = wizard_tower.floorPower(x, {'from': accounts[1]} )
        print(f'floor_power {x}: {floor_power}')


    total_floor_power = wizard_tower._totalFloorPower()
    print(f'total_power: ', total_floor_power)

    total_power_snapshot = wizard_tower.totalPowerSnapshot()
    print(f'total_power_snapshot: ', total_power_snapshot)

    active_floors = wizard_tower.activeFloors()
    print(f'active_floors: ', active_floors)

    tx = wizard_battle.attack(0, 2, {'from': accounts[1], 'value': int(floor_balance*2)}) # first wizard attacks second
    tx.wait(1)
    print(f'events: {tx.events}')
    print(f'won: {tx.events["Attack"]["result"]}')
    print(f'Balances after...')
    tower_balance = token.balanceOf(wizard_tower.address);
    print(f'tower balance : {tower_balance}')
    for x in range(1, 3):
        floor_balance = wizard_tower.floorBalance(x, {'from': accounts[1]} )
        print(f'floor_balance {x}: {floor_balance}')

    account_balance = token.balanceOf(accounts[1].address);
    print(f'account : {account_balance}')

    print(f'sleeping more...')
    chain.sleep(60*9)
    chain.mine(1)
    for x in range(1, 3):
        floor_balance = wizard_tower.floorBalance(x, {'from': accounts[1]} )
        print(f'floor_balance {x}: {floor_balance}')

    tx.wait(1)

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
