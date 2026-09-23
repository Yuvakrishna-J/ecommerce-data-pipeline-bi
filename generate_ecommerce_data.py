"""Generate and load synthetic ecommerce data into MySQL."""

from datetime import date, timedelta
from decimal import Decimal

import numpy as np
import pandas as pd
from faker import Faker
from sqlalchemy import create_engine, text


DATABASE_URL = "mysql+pymysql://root:YOUR_PASSWORD@localhost/ecommerce_db"
CUSTOMER_COUNT = 1_000
PRODUCT_COUNT = 50
ORDER_COUNT = 5_000
RANDOM_SEED = 42


def build_customers(fake: Faker, rng: np.random.Generator) -> pd.DataFrame:
    countries = np.array(["USA", "UK", "Spain", "Canada", "Australia"])
    registration_start = date(2022, 1, 1)
    registration_end = date(2025, 12, 31)
    registration_days = (registration_end - registration_start).days

    registration_dates = [
        registration_start + timedelta(days=int(days))
        for days in rng.integers(0, registration_days + 1, CUSTOMER_COUNT)
    ]

    return pd.DataFrame(
        {
            "customer_name": [fake.name() for _ in range(CUSTOMER_COUNT)],
            "email": [f"customer_{index + 1}@example.com" for index in range(CUSTOMER_COUNT)],
            "country": rng.choice(countries, size=CUSTOMER_COUNT),
            "registration_date": registration_dates,
        }
    )


def build_products(rng: np.random.Generator) -> pd.DataFrame:
    product_catalog = [
        ("Ultrabook Laptop 14-inch", "Laptops"),
        ("Gaming Laptop 15-inch", "Laptops"),
        ("Business Laptop 13-inch", "Laptops"),
        ("27-inch 4K Monitor", "Monitors"),
        ("34-inch Ultrawide Monitor", "Monitors"),
        ("24-inch Full HD Monitor", "Monitors"),
        ("Mechanical Gaming Keyboard", "Keyboards"),
        ("Wireless Office Keyboard", "Keyboards"),
        ("Ergonomic Split Keyboard", "Keyboards"),
        ("Wireless Gaming Mouse", "Mice"),
        ("Ergonomic Vertical Mouse", "Mice"),
        ("Bluetooth Travel Mouse", "Mice"),
        ("Noise-Cancelling Headphones", "Audio"),
        ("Wireless Studio Headphones", "Audio"),
        ("USB Desktop Microphone", "Audio"),
        ("1080p USB Webcam", "Webcams"),
        ("4K Streaming Webcam", "Webcams"),
        ("Wi-Fi 6 Router", "Networking"),
        ("Mesh Wi-Fi Three-Pack", "Networking"),
        ("8-Port Gigabit Switch", "Networking"),
        ("Portable 1TB SSD", "Storage"),
        ("2TB NVMe SSD", "Storage"),
        ("4TB External Hard Drive", "Storage"),
        ("USB-C Flash Drive 256GB", "Storage"),
        ("16GB DDR5 Memory Kit", "Components"),
        ("32GB DDR5 Memory Kit", "Components"),
        ("8-Core Desktop Processor", "Components"),
        ("Midrange Graphics Card", "Components"),
        ("650W Modular Power Supply", "Components"),
        ("Liquid CPU Cooler 240mm", "Components"),
        ("Compact ATX PC Case", "Components"),
        ("USB-C Docking Station", "Accessories"),
        ("65W GaN Wall Charger", "Accessories"),
        ("100W USB-C Charging Cable", "Accessories"),
        ("Thunderbolt 4 Cable", "Accessories"),
        ("Multi-Port USB Hub", "Accessories"),
        ("Adjustable Aluminum Laptop Stand", "Accessories"),
        ("Dual Monitor Arm", "Accessories"),
        ("Surge Protector 12-Outlet", "Accessories"),
        ("Smartphone Gimbal Stabilizer", "Mobile"),
        ("10-inch Android Tablet", "Mobile"),
        ("Smartphone Power Bank 20,000mAh", "Mobile"),
        ("E-Reader 6-inch", "Mobile"),
        ("Fitness Smartwatch", "Wearables"),
        ("USB-C Smartwatch Charger", "Wearables"),
        ("Bluetooth Tracker Four-Pack", "Wearables"),
        ("Laser Printer", "Printers"),
        ("Wireless Color Printer", "Printers"),
        ("Document Scanner", "Printers"),
        ("4K Action Camera", "Cameras"),
    ]
    base_prices = rng.uniform(14.99, 1_799.99, PRODUCT_COUNT).round(2)
    stock = rng.integers(25, 500, PRODUCT_COUNT)

    return pd.DataFrame(
        {
            "product_name": [product[0] for product in product_catalog],
            "category": [product[1] for product in product_catalog],
            "price": base_prices,
            "stock_quantity": stock,
        }
    )


def build_orders(
    customers: pd.DataFrame,
    products: pd.DataFrame,
    rng: np.random.Generator,
) -> pd.DataFrame:
    selected_customers = customers.iloc[
        rng.integers(0, len(customers), ORDER_COUNT)
    ].reset_index(drop=True)
    selected_products = products.iloc[
        rng.integers(0, len(products), ORDER_COUNT)
    ].reset_index(drop=True)
    quantities = rng.integers(1, 6, ORDER_COUNT)

    today = date.today()
    order_dates = []
    for registration_date in selected_customers["registration_date"]:
        days_available = max(0, (today - registration_date).days)
        order_dates.append(
            registration_date + timedelta(days=int(rng.integers(days_available + 1)))
        )

    prices = selected_products["price"].astype(float)
    return pd.DataFrame(
        {
            "customer_id": selected_customers["customer_id"].astype(int),
            "product_id": selected_products["product_id"].astype(int),
            "order_date": order_dates,
            "quantity": quantities,
            "total_amount": (prices * quantities).round(2),
        }
    )


def main() -> None:
    fake = Faker()
    Faker.seed(RANDOM_SEED)
    rng = np.random.default_rng(RANDOM_SEED)
    engine = create_engine(DATABASE_URL, future=True)

    customers = build_customers(fake, rng)
    products = build_products(rng)

    with engine.begin() as connection:
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
        connection.execute(text("TRUNCATE TABLE Orders"))
        connection.execute(text("TRUNCATE TABLE Customers"))
        connection.execute(text("TRUNCATE TABLE Products"))
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 1"))

    customers.to_sql("Customers", engine, if_exists="append", index=False, method="multi")
    products.to_sql("Products", engine, if_exists="append", index=False, method="multi")

    # Read database-assigned IDs so orders always reference existing rows.
    customers_db = pd.read_sql(
        text("SELECT customer_id, registration_date FROM Customers ORDER BY customer_id"),
        engine,
    )
    products_db = pd.read_sql(
        text("SELECT product_id, price FROM Products ORDER BY product_id"), engine
    )
    orders = build_orders(customers_db, products_db, rng)
    orders.to_sql("Orders", engine, if_exists="append", index=False, method="multi")

    with engine.connect() as connection:
        counts = pd.read_sql(
            text(
                "SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM Customers "
                "UNION ALL SELECT 'Products', COUNT(*) FROM Products "
                "UNION ALL SELECT 'Orders', COUNT(*) FROM Orders"
            ),
            connection,
        )
        invalid_dates = connection.execute(
            text(
                "SELECT COUNT(*) FROM Orders o "
                "JOIN Customers c ON c.customer_id = o.customer_id "
                "WHERE o.order_date < c.registration_date"
            )
        ).scalar_one()
        invalid_totals = connection.execute(
            text(
                "SELECT COUNT(*) FROM Orders o "
                "JOIN Products p ON p.product_id = o.product_id "
                "WHERE o.total_amount <> o.quantity * p.price"
            )
        ).scalar_one()

    expected_counts = {"Customers": CUSTOMER_COUNT, "Products": PRODUCT_COUNT, "Orders": ORDER_COUNT}
    actual_counts = dict(zip(counts["table_name"], counts["row_count"]))
    assert actual_counts == expected_counts, (actual_counts, expected_counts)
    assert invalid_dates == 0, f"Found {invalid_dates} orders before registration"
    assert invalid_totals == 0, f"Found {invalid_totals} incorrect order totals"

    print("Synthetic ecommerce data loaded successfully.")
    print(counts.to_string(index=False))


if __name__ == "__main__":
    main()