const http = require('http');

async function testApi() {
  console.log('--- Testing Backend API ---\n');

  try {
    const uniqueEmail = `testuser_${Date.now()}@sekolah.id`;
    
    // 1. Test Register
    console.log(`1. Testing Register API (/auth/register) with ${uniqueEmail}...`);
    const registerData = JSON.stringify({
      email: uniqueEmail,
      password: 'password123',
      full_name: 'Test User'
    });

    const registerResponse = await new Promise((resolve, reject) => {
      const req = http.request({
        hostname: 'localhost',
        port: 3000,
        path: '/auth/register',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(registerData)
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(data) }));
      });
      req.on('error', reject);
      req.write(registerData);
      req.end();
    });

    if (registerResponse.status === 200 && registerResponse.data.token) {
      console.log('✅ Register successful! Token received.');
    } else {
      console.log('❌ Register failed:', registerResponse);
      return; 
    }

    const token = registerResponse.data.token;

    // 2. Test Get Students (protected route)
    console.log('\n2. Testing Get Students API (/api/students) with Token...');
    const studentsResponse = await new Promise((resolve, reject) => {
      const req = http.request({
        hostname: 'localhost',
        port: 3000,
        path: '/api/students',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(data) }));
      });
      req.on('error', reject);
      req.end();
    });

    if (studentsResponse.status === 200 && Array.isArray(studentsResponse.data)) {
      console.log(`✅ Get Students successful! Found ${studentsResponse.data.length} students.`);
      console.log('Sample data:', studentsResponse.data[0]);
    } else {
      console.log('❌ Get Students failed:', studentsResponse);
    }

    console.log('\n--- All API tests completed successfully ---');
    
  } catch (error) {
    console.error('Error during testing:', error);
  }
}

testApi();
