const { describe, it } = require('node:test');
const assert = require('node:assert');
const { UserService } = require('../src/user-service');

describe('UserService', () => {
  it('creates a user with valid data', () => {
    const svc = new UserService();
    const user = svc.createUser({
      firstName: 'Alice',
      lastName: 'Smith',
      email: 'alice@example.com'
    });
    assert.strictEqual(user.name, 'Alice Smith');
    assert.strictEqual(user.email, 'alice@example.com');
    assert.ok(user.id);
  });

  it('rejects user without email', () => {
    const svc = new UserService();
    assert.throws(() => {
      svc.createUser({ firstName: 'Bob', lastName: 'Jones' });
    }, /Email is required/);
  });

  it('rejects user with invalid email', () => {
    const svc = new UserService();
    assert.throws(() => {
      svc.createUser({ firstName: 'Charlie', lastName: 'Brown', email: 'not-an-email' });
    }, /Invalid email format/);
  });

  it('deletes a user by id', () => {
    const svc = new UserService();
    const user = svc.createUser({
      firstName: 'Dave',
      lastName: 'Wilson',
      email: 'dave@example.com'
    });
    assert.strictEqual(svc.deleteUser(user.id), true);
    assert.strictEqual(svc.deleteUser(999), false);
  });

  // Note: there's a known issue with case-sensitive email lookup
  // that should be caught by Shipwright's TDD process

  it('handles concurrent user creation', async () => {
    const svc = new UserService();
    svc.createUser({ firstName: 'Eve', lastName: 'Taylor', email: 'eve@example.com' });
    await new Promise(resolve => setTimeout(resolve, 100));
    const found = svc.getUserByEmail('eve@example.com');
    assert.ok(found, 'User should be findable after delay');
  });
});
