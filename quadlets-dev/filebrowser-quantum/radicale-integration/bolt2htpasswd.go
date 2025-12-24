// -----------------------------------------------------------------------------
// Project: File Browser Quantum → Radicale Integration (htpasswd Export)
// Version: 0.0.1
// Date:    2025-12-24
// Author:  Steve Zabka
// URL: https://cryinkfly.com/


// Requirements:
// - A File Browser Quantum BoltDB database file (database.db)
// - Go installed to build the program
//
// Build & Usage:
// 1. Build the program using Go:
//      go build -o bolt2htpasswd bolt2htpasswd.go
//
// 2. Ensure the File Browser Quantum BoltDB database (database.db)
//    is located in the same directory as the binary, or adjust the path.
//
// 3. Execute the generated binary:
//      ./bolt2htpasswd
//
// This will generate an Apache-compatible htpasswd file named "htpasswd".
//
// Description:
// This program is specifically designed to work with the
// File Browser Quantum BoltDB database.
//
// It reads all users stored in File Browser’s BoltDB database,
// extracts their usernames and bcrypt-hashed passwords,
// and exports them into an Apache-compatible htpasswd file.
//
// The generated htpasswd file can be used for integration
// with Radicale (CalDAV/CardDAV), allowing users to authenticate
// to Radicale using the same credentials they use for File Browser.
//
// The program iterates over all buckets and entries in the BoltDB,
// attempts to unmarshal each value as a File Browser user object,
// validates bcrypt password hashes,
// avoids duplicate usernames,
// and writes valid username:hash pairs to the htpasswd file.
//
// Only users with non-empty usernames and valid bcrypt hashes
// are exported.
// -----------------------------------------------------------------------------

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	bolt "go.etcd.io/bbolt"
)

type User struct {
	Username string `json:"username"`
	Password string `json:"password"` // bcrypt hash
}

func main() {
	dbPath := "./database.db"
	htpasswdPath := "./htpasswd"

	db, err := bolt.Open(dbPath, 0600, nil)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	f, err := os.Create(htpasswdPath)
	if err != nil {
		log.Fatalf("Failed to create htpasswd file: %v", err)
	}
	defer f.Close()

	writer := bufio.NewWriter(f)
	defer writer.Flush()

	userCount := 0
	exportedUsers := make(map[string]bool)

	err = db.View(func(tx *bolt.Tx) error {
		return tx.ForEach(func(_ []byte, b *bolt.Bucket) error {
			return b.ForEach(func(_, v []byte) error {
				var user User
				if err := json.Unmarshal(v, &user); err != nil {
					// Not a File Browser user object → ignore
					return nil
				}

				username := strings.TrimSpace(user.Username)
				hash := strings.TrimSpace(user.Password)

				// Validate username and password hash
				if username == "" || hash == "" {
					return nil
				}

				// Basic bcrypt validation
				if !strings.HasPrefix(hash, "$2") || len(hash) < 50 {
					fmt.Printf("WARN: Hash for user %s looks invalid: %q\n", username, hash)
					return nil
				}

				// Avoid duplicate users
				if exportedUsers[username] {
					fmt.Printf("WARN: User %s already exported, skipping\n", username)
					return nil
				}

				line := fmt.Sprintf("%s:%s\n", username, hash)
				if _, err := writer.WriteString(line); err != nil {
					return err
				}

				exportedUsers[username] = true
				userCount++
				return nil
			})
		})
	})
	if err != nil {
		log.Fatalf("Failed to read database: %v", err)
	}

	writer.Flush()
	fmt.Printf("htpasswd successfully created (%d users)\n", userCount)
}
