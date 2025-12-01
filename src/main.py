from __future__ import annotations

import argparse
import asyncio
import logging
import os
from pathlib import Path

import aiofiles.os

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s - %(message)s",
    datefmt="%H:%M:%S",
)


async def read_folder(source: Path, output: Path):
    tasks = []
    for root, _, files in os.walk(source):
        for file in files:
            file_path = Path(root) / file
            tasks.append(copy_file(file_path, output))
    await asyncio.gather(*tasks)


async def copy_file(file_path: Path, output: Path):
    try:
        extension = file_path.suffix[1:]
        if not extension:
            extension = "no_extension"

        subfolder = output / extension
        await aiofiles.os.makedirs(subfolder, exist_ok=True)

        destination = subfolder / file_path.name
        async with aiofiles.open(file_path, "rb") as src_file:
            async with aiofiles.open(destination, "wb") as dest_file:
                await dest_file.write(await src_file.read())

        logging.info(f"Copied {file_path} to {subfolder}")

    except Exception as e:
        logging.error(f"Failed to copy {file_path}: {e}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Sort files by extension asynchronously.",
    )
    parser.add_argument("--source", type=Path, required=True, help="Source folder path")
    parser.add_argument("--output", type=Path, required=True, help="Output folder path")
    return parser.parse_args()


async def main():
    args = parse_args()
    source = args.source
    output = args.output

    if not source.exists() or not source.is_dir():
        raise ValueError(
            f"Source folder {source} does not exist or is not a directory.",
        )
    if not output.exists():
        await aiofiles.os.makedirs(output, exist_ok=True)

    await read_folder(source, output)


if __name__ == "__main__":
    asyncio.run(main())
