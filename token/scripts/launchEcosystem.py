#!/usr/bin/python3

from brownie import Wizards, Token, WizardTower, WizardBattle, Governance, accounts, network, config
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
    governance = Governance.deploy(wizards.address, {'from': accounts[0]})

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
    tx = token.transfer(wizard_tower.address, 10**10, {'from': accounts[0]} )
    tx.wait(1)

    # chain.sleep(60*9)
    # chain.mine(1)

    # for i in range(5):
    #     outcome = wizard_battle.battle(0, 1)
    #     print(f' battle outcome: {outcome}')
    #     chain.sleep(60)
    #     chain.mine(1)
    #
    # for i in range(5):
    #     outcome = wizard_battle.battle(1, 0)
    #     print(f' battle outcome: {outcome}')
    #     chain.sleep(60)
    #     chain.mine(1)


# Governance
#     function createTaskType(string calldata _IPFSHash, uint8 _numFieldsToHash, uint24 _timeBonus, uint40 _begTimestamp,
#                 uint40 _endTimestamp, uint40 _availableSlots) external onlyBoard {

    '''
    hex_string = "FirstOne"
    tx = governance.createTaskType(hex_string, 1, 24*60*60, 0, 999999999999, 25)
    tx.wait(1)
    tasks = governance.getMyAvailableTaskTypes()
    print(f'my tasks: {tasks}')
    print(f'events: {tx.events}')
    tt = governance.getTaskTypeFields(0);
    print(f'tt: {tt}')

    hex_string = "SecondOne"
    tx = governance.createTaskType(hex_string, 5, 24*60*60, 0, 999999999999, 25)
    tx.wait(1)
    tasks = governance.getMyAvailableTaskTypes()
    print(f'my tasks: {tasks}')
    print(f'events: {tx.events}')
    tt = governance.getTaskTypeFields(1)
    print(f'tt: {tt}')
    '''
    # not refuted
    # hex_string = 0xc9d2b9a1987d380a8c8b45cf8ad43d19ccea73584eb50c57bd601558fc64a404
    bytes_array = ["0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8", "0x18e9b451e5bb9a4a819352109126d2346a89373c4522fc9538ca265404dae958" ]

    # refuted
    hex_string = 0xfdc8dd941e43d934262f1805847ae879102598ee969b05eee95efbe8d9c21646
    # bytes_array = ["0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8", "0x18e9b451e5bb9a4a819352109126d2346a89373c4522fc9538ca265404dae958"]

    # bytes_array = [ "0x00000000000000000000000000000000000000000000000000000068656c6c6f", "0x0000000000000000000000000000000000000000000000000000006d6f74746f" ]

    tx = governance.testHashing(hex_string, bytes_array, True)
    tx.wait(1)
    print(f'events: {tx.events}')

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
