function formatUserName(first, last) {
  return `${first} ${last}`;
}

function validateEmail(email) {
  if (!email || typeof email !== 'string') return false;
  return email.includes('@') && email.includes('.');
}

function ProcessData(items) {
  const result = [];
  for (let i = 0; i < items.length; i++) {
    result.push(items[i].value * 2);
  }
  return result;
}

module.exports = { formatUserName, validateEmail, ProcessData };
