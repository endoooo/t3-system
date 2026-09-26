defmodule T3System.CloudinaryTest do
  use ExUnit.Case, async: true

  alias T3System.Cloudinary

  @image_path "test/support/fixtures/player.png"

  describe "upload_image/2" do
    test "sends a signed upload and returns the secure url" do
      Req.Test.stub(Cloudinary, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1_1/test-cloud/image/upload"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ ~s(name="api_key"\r\n\r\ntest-key)
        assert body =~ ~s(name="folder"\r\n\r\nplayers)
        assert body =~ ~s(name="file")

        [_, timestamp] = Regex.run(~r/name="timestamp"\r\n\r\n(\d+)/, body)
        [_, signature] = Regex.run(~r/name="signature"\r\n\r\n(\w+)/, body)

        expected =
          :crypto.hash(
            :sha,
            "folder=players&timestamp=#{timestamp}&transformation=c_limit,w_800,h_800test-secret"
          )
          |> Base.encode16(case: :lower)

        assert signature == expected

        Req.Test.json(conn, %{"secure_url" => "https://res.cloudinary.com/test-cloud/p.png"})
      end)

      assert Cloudinary.upload_image(@image_path, "players") ==
               {:ok, "https://res.cloudinary.com/test-cloud/p.png"}
    end

    test "returns the api error message on failure" do
      Req.Test.stub(Cloudinary, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid Signature"}})
      end)

      assert Cloudinary.upload_image(@image_path, "players") == {:error, "Invalid Signature"}
    end
  end
end
