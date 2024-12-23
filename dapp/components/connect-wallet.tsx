import { ConnectButton } from "@rainbow-me/rainbowkit"
import { Button } from "./ui/button"

const CustomConnectButton = ({
  className = "",
  variant = "default",
  size = "default",
}: {
  className?: string
  variant?:
    | "default"
    | "destructive"
    | "outline"
    | "secondary"
    | "ghost"
    | "link"
  size?: "default" | "sm" | "lg" | "icon"
}) => {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        const ready = mounted
        const connected = ready && account && chain

        return (
          <div
            {...(!ready && {
              "aria-hidden": true,
              style: {
                opacity: 0,
                pointerEvents: "none",
                userSelect: "none",
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <Button
                    onClick={openConnectModal}
                    variant={variant}
                    size={size}
                    className={className}
                  >
                    Connect Wallet
                  </Button>
                )
              }

              if (chain.unsupported) {
                return (
                  <Button variant="destructive" onClick={openChainModal}>
                    Wrong Network
                  </Button>
                )
              }

              return (
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    onClick={openChainModal}
                    className="flex items-center gap-2"
                  >
                    {chain.hasIcon && (
                      <div className="w-4 h-4">
                        {chain.iconUrl && (
                          <img
                            alt={chain.name ?? "Chain icon"}
                            src={chain.iconUrl}
                            className="w-4 h-4"
                          />
                        )}
                      </div>
                    )}
                    {chain.name}
                  </Button>

                  <Button onClick={openAccountModal}>
                    {account.displayName}
                    {account.displayBalance
                      ? ` (${account.displayBalance})`
                      : ""}
                  </Button>
                </div>
              )
            })()}
          </div>
        )
      }}
    </ConnectButton.Custom>
  )
}

export default CustomConnectButton
