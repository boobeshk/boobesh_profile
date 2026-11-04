"""Packages a Boomi component and deploys it to an environment: a CI/CD step for Boomi integrations.

Usage:
    python deploy_package.py --component <componentId> --environment <environmentId> --version 1.4.0 \
        --notes "Release 1.4.0: retry on 5xx from SAP"
"""

import argparse

from boomi_api import BoomiClient


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--component", required=True, help="ID of the process or API component to release")
    parser.add_argument("--environment", required=True, help="ID of the target environment (Test, Prod, ...)")
    parser.add_argument("--version", required=True, help="Package version label, for example 1.4.0")
    parser.add_argument("--notes", default="", help="Release notes stored with the package and deployment")
    args = parser.parse_args()

    client = BoomiClient()

    # 1. Freeze the current component revision into an immutable package.
    package = client.post(
        "PackagedComponent",
        {"componentId": args.component, "packageVersion": args.version, "notes": args.notes},
    )
    print(f"Packaged {args.component} as version {args.version}: packageId={package['packageId']}")

    # 2. Deploy that exact package to the environment; the Molecule picks it up automatically.
    deployment = client.post(
        "DeployedPackage",
        {"environmentId": args.environment, "packageId": package["packageId"], "notes": args.notes},
    )
    print(f"Deployed to environment {args.environment}: deploymentId={deployment['deploymentId']}")


if __name__ == "__main__":
    main()
