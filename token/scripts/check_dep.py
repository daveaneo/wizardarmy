#!/usr/bin/python3
import json


def check_dependencies(package_file, required_dependencies):
    with open(package_file, 'r') as f:
        data = json.load(f)

    # Check if 'devDependencies' section exists
    if "devDependencies" not in data:
        print("The 'devDependencies' section is missing in package.json!")
        return

    missing_deps = []
    for dep, version in required_dependencies.items():
        if dep not in data['devDependencies']:
            missing_deps.append(f"{dep}@{version} (Not Installed)")
        elif data['devDependencies'][dep] != version:
            missing_deps.append(f"{dep}@{version} (Current: {data['devDependencies'][dep]})")

    if missing_deps:
        print("Missing or incorrect version of dependencies:")
        for dep in missing_deps:
            print(f"- {dep}")
    else:
        print("All required dependencies are correctly installed!")


if __name__ == "__main__":
    REQUIRED_DEPENDENCIES = {
        "hardhat": "2.17.3",
        "ethers": "5.7.2",
        "@nomiclabs/hardhat-ethers": "2.2.3",
        "@nomiclabs/hardhat-waffle": "2.0.6"
    }

    check_dependencies("package.json", REQUIRED_DEPENDENCIES)
