#!/usr/bin/python3

from brownie import Wizards, Token, accounts, config
import json

DUMP_ABI = True

dev = accounts.add(config["wallets"]["from_key"]) # accounts[0]
secondary = accounts.add(config["wallets"]["secondary"]) # accounts[1]


def main():
    token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})
    wizards = Wizards.deploy("Wizards", "WZD", token.address, {'from': accounts[0]})
    ts = wizards.totalSupply()
    print(f'total supply: {ts}')
    tx = wizards.mint({'from': accounts[0]})
    tx.wait(1)
    ts = wizards.totalSupply()
    print(f'total supply: {ts}')

    if DUMP_ABI:
        import os
        print(f'dumping abi...') # sdf sfd sdfsdf sdf
        dir = os.getcwd()
        path = os.path.join(dir, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizards.abi)
        file_path = os.path.join(path, "wizards.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)

    # return Wizards.deploy("Wizards", "WZD", {'from': accounts[0]})
