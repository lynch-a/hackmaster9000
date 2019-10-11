    
/*
 * Copyright (c) 2010-2019 Nathan Rajlich
 *
 *  Permission is hereby granted, free of charge, to any person
 *  obtaining a copy of this software and associated documentation
 *  files (the "Software"), to deal in the Software without
 *  restriction, including without limitation the rights to use,
 *  copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following
 *  conditions:
 *
 *  The above copyright notice and this permission notice shall be
 *  included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 */

import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Map;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.drafts.Draft;
import org.java_websocket.handshake.ServerHandshake;

import com.google.gson.FieldNamingPolicy;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;

/** This example demonstrates how to create a websocket connection to a server. Only the most important callbacks are overloaded. */
public class TerminalServer extends WebSocketClient {

	public TerminalServer( URI serverUri , Draft draft ) {
		super( serverUri, draft );
	}

	public TerminalServer( URI serverURI ) {
		super( serverURI );
	}

	public TerminalServer( URI serverUri, Map<String, String> httpHeaders ) {
		super(serverUri, httpHeaders);
	}

	@Override
	public void onOpen( ServerHandshake handshakedata ) {
		// send auth to tell terminal-server we are a special client
		
		JsonObject auth_request = new JsonObject();
        auth_request.addProperty("event", "auth");
        
        String hackJob_secret = "";
        try {
	        hackJob_secret = new String(Files.readAllBytes(Paths.get("hackjob_secret.txt")));
        } catch (Exception e) {
        	System.out.println("Couldn't read secret key for scheduler service (does hackjob_secret.txt exist?), exiting");
        	System.exit(1);
        }
        
        JsonObject data_object = new JsonObject();
        data_object.addProperty("terminal_token", hackJob_secret);
        auth_request.add("data", data_object);
        
        Gson gson = new GsonBuilder().setPrettyPrinting().serializeNulls().setFieldNamingPolicy(FieldNamingPolicy.UPPER_CAMEL_CASE).create();
        //System.out.println("sending to TS: " + gson.toJson(auth_request));
        
		send(gson.toJson(auth_request));
		
		System.out.println( "opened WS connection, sent auth" );
		// if you plan to refuse connection based on ip or httpfields overload: onWebsocketHandshakeReceivedAsClient
	}

	@Override
	public void onMessage( String message ) {
		//System.out.println( "received: " + message );
		// the scheduler might receive jobs back from the terminal server, handle them here
	}

	@Override
	public void onClose( int code, String reason, boolean remote ) {
		// The codecodes are documented in class org.java_websocket.framing.CloseFrame
		System.out.println( "WS Connection closed by " + ( remote ? "remote peer" : "us" ) + " Code: " + code + " Reason: " + reason );
	}

	@Override
	public void onError( Exception ex ) {
		ex.printStackTrace();
		// if the error is fatal then onClose will be called additionally
	}
}