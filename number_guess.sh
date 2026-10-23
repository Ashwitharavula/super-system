#!/bin/bash

DB_NAME="number_guessing_game"
DB_USER="freecodecamp"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/number_guess.sql"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run this game." >&2
  exit 1
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'freecodecamp';" 2>/dev/null | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER freecodecamp WITH CREATEDB;" >/dev/null 2>&1 || true
fi

if ! sudo -u postgres psql -lqt 2>/dev/null | cut -d '|' -f 1 | tr -d ' ' | grep -qx "$DB_NAME"; then
  sudo -u postgres createdb -O "$DB_USER" "$DB_NAME" >/dev/null 2>&1 || true
fi

if ! psql -X --username="$DB_USER" --dbname="$DB_NAME" -tAc "SELECT 1 FROM information_schema.tables WHERE table_name = 'users';" 2>/dev/null | grep -q 1; then
  psql -X --username="$DB_USER" --dbname="$DB_NAME" < "$SQL_FILE"
fi

echo -n "Enter your username: "
read USERNAME
USERNAME="${USERNAME//\'/''}"

USER_ID=$(psql -X --username="$DB_USER" --dbname="$DB_NAME" -tAc "SELECT user_id FROM users WHERE username = '$USERNAME';")

if [[ -z "$USER_ID" ]]; then
  psql -X --username="$DB_USER" --dbname="$DB_NAME" -c "INSERT INTO users(username) VALUES('$USERNAME');" >/dev/null
  USER_ID=$(psql -X --username="$DB_USER" --dbname="$DB_NAME" -tAc "SELECT user_id FROM users WHERE username = '$USERNAME';")
  echo "Welcome, $USERNAME! It looks like this is your first time here."
else
  GAMES_PLAYED=$(psql -X --username="$DB_USER" --dbname="$DB_NAME" -tAc "SELECT COUNT(*) FROM games WHERE user_id = $USER_ID;")
  BEST_GAME=$(psql -X --username="$DB_USER" --dbname="$DB_NAME" -tAc "SELECT MIN(guesses) FROM games WHERE user_id = $USER_ID;")
  echo "Welcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
fi

SECRET_NUMBER=$(( RANDOM % 1000 + 1 ))
TRIES=0

while true; do
  ((TRIES++))
  echo -n "Guess the secret number between 1 and 1000: "
  read GUESS

  if [[ ! "$GUESS" =~ ^[0-9]+$ ]]; then
    echo "That is not an integer, guess again:"
    continue
  fi

  if (( GUESS < SECRET_NUMBER )); then
    echo "It's higher than that, guess again:"
  elif (( GUESS > SECRET_NUMBER )); then
    echo "It's lower than that, guess again:"
  else
    psql -X --username="$DB_USER" --dbname="$DB_NAME" -c "INSERT INTO games(user_id, guesses) VALUES($USER_ID, $TRIES);" >/dev/null
    echo "You guessed it in $TRIES tries. The secret number was $SECRET_NUMBER. Nice job!"
    exit 0
  fi
done
