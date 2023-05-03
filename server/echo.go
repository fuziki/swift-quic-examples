package main

import (
	"context"
	"crypto/tls"
	"log"

	"github.com/alta/insecure"
	"github.com/quic-go/quic-go"
)

func main() {
	err := serve(":4433")
	if err != nil {
		log.Fatal(err)
	}
}

func serve(addr string) error {
	cert, err := insecure.Cert()
	if err != nil {
		return err
	}
	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
		NextProtos:   []string{"echo"},
	}
	quicConfig := &quic.Config{
		EnableDatagrams: true,
	}
	listener, err := quic.ListenAddr(addr, tlsConfig, quicConfig)
	if err != nil {
		return err
	}

	log.Printf("Start Listening!")

	for {
		conn, err := listener.Accept(context.Background())
		if err != nil {
			return err
		}
		log.Println("conn: ", conn)
		go handleStream(conn)
		go handleDatagram(conn)
	}
}

func handleStream(conn quic.Connection) {
	str, err := conn.AcceptStream(context.Background())
	if err != nil {
		panic(err)
	}
	log.Println("stream: ", str)

	for {
		bytes := make([]byte, 32)
		read, err := str.Read(bytes)
		log.Printf("read: %#v, %v, %v", read, bytes, err)
		if err != nil {
			break
		}

		wrote, err := str.Write(bytes[0:read])
		log.Printf("write: %#v, %v", wrote, err)
		if err != nil {
			break
		}
	}
	str.Close()
}

func handleDatagram(conn quic.Connection) {
	for {
		bytes, err := conn.ReceiveMessage()
		log.Printf("receive: %#v, %v", bytes, err)
		if err != nil {
			break
		}

		err = conn.SendMessage(bytes)
		log.Printf("write: %#v", err)
		if err != nil {
			break
		}
	}
}
