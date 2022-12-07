#!/usr/bin/env python

# https://github.com/anishathalye/dotbot/wiki/Tips-and-Tricks#uninstall-script
import yaml
import os
import logging
import glob

logging.basicConfig()
logging.getLogger().setLevel(logging.INFO)

dotfile_groups = os.getenv("DOTFILE_GROUPS")
groups = dotfile_groups.split(",") if dotfile_groups else None

if groups and len(groups) > 0:
    logging.info(f"""Remove links from {", ".join(map(lambda f: f"{f}.yml", groups))}.""")
    for group in groups:
        stream = open(f"{group}.yml", "r")
        conf = yaml.load(stream, yaml.FullLoader)
        for section in conf:
            if "link" in section:
                for target in section["link"]:
                    realpath = os.path.expanduser(target)
                    logging.debug(f"Checking path: {realpath}")
                    if os.path.islink(realpath):
                        logging.info(f"Removing link: {realpath}")
                        os.unlink(realpath)
else:
    logging.warning("No groups found. Set DOTFILE_GROUPS environment variable to uninstall.")
    available_config_files = filter(lambda f: f if f not in ["uninstall.yml"] else None, glob.glob("*.yml"))
    available_dotfile_groups = ", ".join(map(lambda f: os.path.splitext(f)[0], available_config_files))
    logging.info(F"Available DOTFILE_GROUPS: {available_dotfile_groups}.")
