# Manual test script to run from the terminal; do not run this script automatically.

from tools.search_tours import search_tours


def main():
    tours = search_tours(destination_id=1)

    if not tours:
        print("No tours found.")
        return

    print("Tours for destination ID 1:")
    for tour in tours:
        print(
            f"- Name: {tour.get('name', 'N/A')} | "
            f"Price: {tour.get('price', 'N/A')} | "
            f"Status: {tour.get('status', 'N/A')}"
        )


if __name__ == "__main__":
    main()
