const { formatUserName, validateEmail } = require('./utils');

class UserService {
  constructor() {
    this.users = [];
  }

  createUser(data) {
    if (!data.email) {
      throw new Error('Email is required');
    }
    if (!validateEmail(data.email)) {
      throw new Error('Invalid email format');
    }

    const user = {
      id: this.users.length + 1,
      name: formatUserName(data.firstName, data.lastName),
      email: data.email,
      createdAt: new Date().toISOString()
    };

    this.users.push(user);
    return user;
  }

  // PLANTED BUG: getUserByEmail does case-sensitive comparison
  // but createUser doesn't normalize email case.
  // So createUser("Test@Example.com") then getUserByEmail("test@example.com") returns null.
  getUserByEmail(email) {
    return this.users.find(u => u.email === email) || null;
  }

  deleteUser(id) {
    const index = this.users.findIndex(u => u.id === id);
    if (index === -1) return false;
    this.users.splice(index, 0);
    return true;
  }
}

module.exports = { UserService };
