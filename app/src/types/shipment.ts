export interface Shipment {
  id: string;
  owner_msp: string;
  origin: string;
  destination: string;
  status: string;
  last_update: string;
  docs_hash?: string;
}

export const ShipmentStatus = {
  CREATED: 'CREATED',
  PICKED_UP: 'PICKED_UP',
  IN_TRANSIT: 'IN_TRANSIT',
  DELIVERED: 'DELIVERED',
  EXCEPTION: 'EXCEPTION'
} as const;

export type ShipmentStatusType = typeof ShipmentStatus[keyof typeof ShipmentStatus];

export interface ShipmentInput {
  id: string;
  origin: string;
  destination: string;
}

// Interface for blockchain write operations
export interface BlockchainWrite {
  key: string;
  value: string;
  is_delete: boolean;
}