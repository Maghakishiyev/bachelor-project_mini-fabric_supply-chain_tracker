import { check } from "k6";
import { FabConnect, submitTx } from "k6/x/fabric";   // x/fabric extension

export const options = {
  vus: 10,
  duration: "5m",
  thresholds: { tx_latency: ["p(90)<250"] },
};

export default () => {
  const id = Math.random().toString(36).slice(2, 10);
  const res = submitTx("supplychain", "shipping", "CreateShipment", id, "W", "B");
  check(res, { "status is 200": (r) => r.status === 200 });
};