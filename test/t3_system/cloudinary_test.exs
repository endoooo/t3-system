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
        assert body =~ ~s(name="folder"\r\n\r\nt3_system_test/players)
        assert body =~ ~s(name="file")

        [_, timestamp] = Regex.run(~r/name="timestamp"\r\n\r\n(\d+)/, body)
        [_, signature] = Regex.run(~r/name="signature"\r\n\r\n(\w+)/, body)

        expected =
          :crypto.hash(
            :sha,
            "folder=t3_system_test/players&timestamp=#{timestamp}&transformation=c_limit,w_800,h_800test-secret"
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

  describe "delete_image/1" do
    test "destroys the image with a signed request" do
      Req.Test.stub(Cloudinary, fn conn ->
        assert conn.request_path == "/v1_1/test-cloud/image/destroy"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["public_id"] == "t3_system_test/players/abc"
        assert params["api_key"] == "test-key"

        expected =
          :crypto.hash(
            :sha,
            "public_id=t3_system_test/players/abc&timestamp=#{params["timestamp"]}test-secret"
          )
          |> Base.encode16(case: :lower)

        assert params["signature"] == expected

        Req.Test.json(conn, %{"result" => "ok"})
      end)

      assert Cloudinary.delete_image(
               "https://res.cloudinary.com/test-cloud/image/upload/v1727/t3_system_test/players/abc.png"
             ) == :ok
    end

    test "treats an already deleted image as success" do
      Req.Test.stub(Cloudinary, &Req.Test.json(&1, %{"result" => "not found"}))

      assert Cloudinary.delete_image(
               "https://res.cloudinary.com/test-cloud/image/upload/v1/players/gone.jpg"
             ) == :ok
    end

    test "ignores nil and URLs from other hosts or accounts without a request" do
      assert Cloudinary.delete_image(nil) == :ok
      assert Cloudinary.delete_image("https://example.com/player.jpg") == :ok

      assert Cloudinary.delete_image(
               "https://res.cloudinary.com/other-cloud/image/upload/v1/players/abc.png"
             ) == :ok
    end
  end

  describe "thumbnail_url/2" do
    test "adds a face-cropped square transformation to Cloudinary URLs" do
      assert Cloudinary.thumbnail_url(
               "https://res.cloudinary.com/test-cloud/image/upload/v1/players/abc.png",
               64
             ) ==
               "https://res.cloudinary.com/test-cloud/image/upload/c_fill,g_face,w_64,h_64,f_auto,q_auto/v1/players/abc.png"
    end

    test "leaves other URLs and nil untouched" do
      assert Cloudinary.thumbnail_url("https://example.com/player.jpg", 64) ==
               "https://example.com/player.jpg"

      assert Cloudinary.thumbnail_url(nil, 64) == nil
    end
  end
end
