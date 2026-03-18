import sqlite3
import sys

def main():
    job_id = "6ebca07a-d98f-4bd6-88a3-051614eaa575"
    conn = sqlite3.connect('smarttrade.db')
    cursor = conn.cursor()
    cursor.execute('SELECT error_message FROM jobs WHERE id=?', (job_id,))
    row = cursor.fetchone()
    if row is not None:
        print("ERROR_MESSAGE:", row[0])
    else:
        print("Job not found")
    conn.close()

if __name__ == "__main__":
    main()
