To use `natools` for message encryption (to destination) and signature (from sender), you would typically follow these steps:

### 1. Generate Key Pairs:
   - Both the sender and the recipient need to generate their key pairs (public and private keys). You can use the `natools` script to generate keys.

   ```bash
   # Sender generate keys
   python3 natools.py privkey -k ~/.zen/game/sender_secret.dunikey -f cred
   python3 natools.py pubkey -k ~/.zen/game/sender_secret.dunikey -o sender_public_key

   # Recipient generates keys
   python3 natools.py privkey -k ~/.zen/game/myswarm_secret.dunikey -f cred
   python3 natools.py pubkey -k ~/.zen/game/myswarm_secret.dunikey -o recipient_public_key
   ```

### 2. Encrypt the Message:
   - The sender uses the recipient's public key to encrypt the message.

   ```bash
   python3 natools.py encrypt -i plaintext.txt -k recipient_public_key -o encrypted_message.bin
   ```

### 3. Sign the Message:
   - The sender signs the original message using their private key.

   ```bash
   python3 natools.py sign -i plaintext.txt -k sender_private_key -o signature.bin
   ```

### 4. Verify the Signature:
   - The recipient uses the sender's public key to verify the signature.

   ```bash
   python3 natools.py verify -i plaintext.txt -p sender_public_key
   ```

   - The script will output "Signature OK!" if the verification is successful.

### 5. Decrypt the Message:
   - The recipient uses their private key to decrypt the message.

   ```bash
   python3 natools.py decrypt -i encrypted_message.bin -k recipient_private_key -o decrypted_message.txt
   ```

Now you have successfully performed message encryption to the destination and signature from the sender using the `natools` script. Adjust the file paths and content as needed for your specific use case.

Note: Ensure that both sender and recipient securely store their private keys. Public keys can be shared openly. The encrypted message, signature, and decrypted message are intermediate files used for illustration; adjust as needed in your application.
