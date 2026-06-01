from auth import get_current_user_id

# Спробуй викликати її з порожнім токеном
try:
    print(get_current_user_id("fake_token"))
except Exception as e:
    print(f"Помилка в auth.py: {e}")