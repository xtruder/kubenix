{ kubenix ? import ./.. { } }:

{
  nginx-deployment = import ./nginx-deployment { inherit kubenix; };
}
