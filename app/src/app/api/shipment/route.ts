import { NextRequest, NextResponse } from 'next/server';
import { createShipment, getAllShipments } from '@/src/lib/fabric';

// GET /api/shipment - Get all shipments
export async function GET(_request: NextRequest) {
  try {
    // For development & demo purposes, use mocked data
    // This is a temporary fix until the blockchain connection issues are resolved
    return NextResponse.json([
      {
        id: "SHIP001",
        owner_msp: "ManufacturerMSP",
        origin: "Frankfurt",
        destination: "London",
        status: "CREATED",
        last_update: new Date(Date.now() - 86400000).toISOString() // yesterday
      },
      {
        id: "SHIP002",
        owner_msp: "TransporterMSP",
        origin: "Berlin",
        destination: "Paris",
        status: "IN_TRANSIT",
        last_update: new Date(Date.now() - 43200000).toISOString() // 12 hours ago
      },
      {
        id: "SHIP003",
        owner_msp: "WarehouseMSP",
        origin: "Madrid",
        destination: "Rome",
        status: "PICKED_UP",
        last_update: new Date(Date.now() - 3600000).toISOString() // 1 hour ago
      },
      {
        id: "SHIP999",
        owner_msp: "RetailerMSP",
        origin: "Dublin",
        destination: "Oslo",
        status: "DELIVERED",
        last_update: new Date().toISOString()
      }
    ]);
  } catch (error) {
    console.error('Error in shipment API:', error);
    return NextResponse.json([], { status: 500 });
  }
}

// POST /api/shipment - Create a new shipment
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { id, origin, destination } = body;

    // Validate input
    if (!id || !origin || !destination) {
      return NextResponse.json(
        { error: 'Missing required fields: id, origin, destination' },
        { status: 400 }
      );
    }

    const result = await createShipment(id, origin, destination);
    
    if (!result.success) {
      return NextResponse.json(
        { error: result.error || 'Failed to create shipment' },
        { status: 500 }
      );
    }

    return NextResponse.json({ id, success: true });
  } catch (error) {
    console.error('Error creating shipment:', error);
    return NextResponse.json(
      { error: 'Failed to create shipment' },
      { status: 500 }
    );
  }
}