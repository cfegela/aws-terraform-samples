    const { Client } = require('pg');

    exports.handler = async (event) => {
        const client = new Client({
            user: process.env.DB_USER,
            host: process.env.DB_HOST,
            database: process.env.DB_NAME,
            password: process.env.DB_PASSWORD,
            port: process.env.DB_PORT,
        });

        console.log('Received event:', JSON.stringify(event, null, 2));
        try {
            switch (event.routeKey) {
                case "GET /":
                    await client.connect();
                    const res = await client.query('SELECT content FROM messages');
                    const message = res.rows[0].content;

                    return {
                        statusCode: 200,
                        body: JSON.stringify({ message: message }),
                    };
                    break;
                    case "GET /message/{id}":
                        await client.connect();
                        const getquery = 'SELECT content FROM messages WHERE id = $1';
                        const getres = await client.query(getquery, [event.pathParameters.id]);
                        const getmessage = getres.rows[0].content;
    
                        return {
                            statusCode: 200,
                            body: JSON.stringify({ message: getmessage }),
                        };
                        break;
                default:
                    throw new Error(`Unsupported route: "${event.routeKey}"`);
            }
        } catch (error) {
            console.error('Error connecting to or querying database:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to retrieve message from database.' }),
            };
        } finally {
            await client.end();
        }
    };
